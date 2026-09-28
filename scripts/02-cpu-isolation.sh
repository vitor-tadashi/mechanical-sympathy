#!/usr/bin/env bash
#
# 02-cpu-isolation.sh - keep the operating system off the isolated CPUs (Guide 02).
#
#   configure_systemd_cpu_affinity  PID 1 and every service inherit OS_CPUS (persistent, reboot)
#   set_workqueue_affinity          unbound kernel workqueues on WORKQUEUE_CPUS (runtime)
#   disable_irqbalance              stop the daemon that would undo manual IRQ placement
#   set_rt_throttling               allow SCHED_FIFO threads to run 100% of the time
#   pin_process <pid> <cpus>        pin a process AND all its threads
#   show_affinity <pid>             affinity of a process and every thread
#
# Runtime pieces (workqueue mask) are lost on reboot; the lowlat-runtime.service
# unit re-applies them at boot (see scripts/systemd/).

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SYSTEMD_SYSTEM_CONF="${SYSTEMD_SYSTEM_CONF:-/etc/systemd/system.conf}"

# Sets CPUAffinity in systemd's manager configuration. PID 1 applies it to itself
# at boot, and every unit it forks inherits it, so all services, user sessions
# (sshd -> bash) and cron jobs start on OS_CPUS only. Kernel threads are not
# affected (they are handled by isolcpus / nohz_full / workqueue masks).
configure_systemd_cpu_affinity() {
	local os_cpus
	os_cpus="${OS_CPUS[*]}"

	log_sub_step "Restricting systemd and all services to CPUs ${os_cpus} (${SYSTEMD_SYSTEM_CONF})"
	set_key_value_line "${SYSTEMD_SYSTEM_CONF}" CPUAffinity "${os_cpus}"

	log_sub_step "Allowing real-time priority up to ${REAL_TIME_PRIORITY} for services (DefaultLimitRTPRIO)"
	set_key_value_line "${SYSTEMD_SYSTEM_CONF}" DefaultLimitRTPRIO "${REAL_TIME_PRIORITY}"

	log_sub_step "Allowing nice down to -20 for services (DefaultLimitNICE=${NICE_LIMIT})"
	set_key_value_line "${SYSTEMD_SYSTEM_CONF}" DefaultLimitNICE "${NICE_LIMIT}"

	log_sub_step "Reboot required for PID 1 to re-read CPUAffinity (daemon-reexec is not enough for running units)"
}

# Unbound workqueues (writeback, deferred work, some driver work) run on any CPU in
# the mask. Bound (per-CPU) workqueues cannot be moved; nohz_full/isolcpus keep most
# of them quiet.
set_workqueue_affinity() {
	local mask
	mask="$(cpu_mask_from_list "${WORKQUEUE_CPUS[@]}")"

	log_sub_step "Unbound workqueues -> CPUs ${WORKQUEUE_CPUS[*]} (mask ${mask})"
	sysfs_write "${mask}" /sys/devices/virtual/workqueue/cpumask

	log_sub_step "Writeback workqueue -> CPUs ${WORKQUEUE_CPUS[*]} (mask ${mask})"
	sysfs_write "${mask}" /sys/bus/workqueue/devices/writeback/cpumask
}

# irqbalance periodically rewrites /proc/irq/*/smp_affinity. With manual placement
# (Guide 04) it must not run. Alternative for mixed hosts: keep it and set
# IRQBALANCE_BANNED_CPULIST in /etc/sysconfig/irqbalance.
disable_irqbalance() {
	log_sub_step "Stopping and disabling irqbalance"
	run_quiet systemctl stop irqbalance
	run_quiet systemctl disable irqbalance
}

# By default SCHED_FIFO/RR tasks may use at most 950ms of every 1s; the kernel then
# forces 50ms of SCHED_OTHER time. A busy-spinning FIFO thread therefore stalls for
# 50ms every second. -1 removes the limit. Only safe when those threads run on
# isolated CPUs: a runaway FIFO thread on a housekeeping CPU will starve kernel threads.
set_rt_throttling() {
	log_sub_step "Disabling real-time throttling (kernel.sched_rt_runtime_us=-1)"
	write_file /etc/sysctl.d/91-lowlat-rt.conf <<'EOF'
# Managed by mechanical-sympathy 02-cpu-isolation.sh
# Allow SCHED_FIFO/RR threads on isolated CPUs to run without the 950ms/1s cap.
kernel.sched_rt_runtime_us = -1
EOF
	run_quiet sysctl -w kernel.sched_rt_runtime_us=-1
}

# pin_process <pid> <cpu list> - pins a process and ALL its threads (taskset -a).
# Accepts "5 7", "5,7" or "5-7".
pin_process() {
	local pid="$1" cpus
	shift
	cpus="$(printf '%s' "$*" | tr -s ' ' ',' | sed 's/^,//; s/,$//')"
	[[ -n "${pid}" && -d "/proc/${pid}" ]] || {
		log_warn "pin_process: invalid pid '${pid}'"
		return 2
	}
	[[ -n "${cpus}" ]] || {
		log_warn "pin_process: no CPUs given"
		return 1
	}
	run taskset -a -cp "${cpus}" "${pid}"
}

# show_affinity <pid> - prints the allowed CPU list and the CPU each thread last ran on.
show_affinity() {
	local pid="$1" task tid list psr comm
	[[ -n "${pid}" && -d "/proc/${pid}" ]] || {
		log_warn "show_affinity: invalid pid '${pid}'"
		return 2
	}
	printf '%-8s %-20s %-4s %s\n' TID AFFINITY_LIST PSR THREAD
	for task in /proc/"${pid}"/task/*; do
		tid="${task##*/}"
		list="$(awk -F'\t' '/^Cpus_allowed_list/{print $2}' "${task}/status" 2>/dev/null)"
		psr="$(awk '{print $39}' "${task}/stat" 2>/dev/null)"
		comm="$(cat "${task}/comm" 2>/dev/null)"
		printf '%-8s %-20s %-4s %s\n' "${tid}" "${list:-?}" "${psr:-?}" "${comm:-?}"
	done
}

apply_cpu_isolation() {
	log_step "systemd CPU affinity and RT limits"
	if require_capability core_isolation; then
		configure_systemd_cpu_affinity
	fi

	log_step "Kernel workqueue CPU mask"
	if require_capability core_isolation; then
		set_workqueue_affinity
	fi

	log_step "irqbalance"
	if require_capability irqbalance_disable; then
		disable_irqbalance
	else
		log_sub_step "Keeping irqbalance enabled on host_class=${HOST_CLASS}"
	fi

	log_step "Real-time throttling"
	if require_capability rt_throttling; then
		set_rt_throttling
	fi
}

# Runtime-only part, called at every boot by lowlat-runtime.service.
apply_cpu_isolation_runtime() {
	log_step "Kernel workqueue CPU mask"
	if require_capability core_isolation; then
		set_workqueue_affinity
	fi
}

# mask_equals <hex mask> <hex mask> - compares cpumasks ignoring leading zeros/commas.
mask_equals() {
	local a="${1//,/}" b="${2//,/}"
	a="${a#"${a%%[!0]*}"}"
	b="${b#"${b%%[!0]*}"}"
	[[ "${a:-0}" == "${b:-0}" ]]
}

pid1_affinity_is() {
	local actual
	actual="$(awk -F'\t' '/^Cpus_allowed_list/{print $2}' /proc/1/status)"
	[[ "$(cpu_list_expand "${actual}")" == "$*" ]]
}

verify_cpu_isolation() {
	local cpu stray mask expected
	if ! host_is_bare_metal; then
		verify_info "host_class=${HOST_CLASS}: CPU isolation not expected"
		return 0
	fi

	verify_check "PID 1 (systemd) affinity is OS_CPUS ($(cpu_list_join "${OS_CPUS[@]}"))" \
		pid1_affinity_is "${OS_CPUS[@]}"
	verify_check "systemd.conf CPUAffinity is set" grep -q '^CPUAffinity=' "${SYSTEMD_SYSTEM_CONF}"

	expected="$(cpu_mask_from_list "${WORKQUEUE_CPUS[@]}")"
	mask="$(cat /sys/devices/virtual/workqueue/cpumask 2>/dev/null || echo 0)"
	verify_check "workqueue cpumask ${mask} (expected ${expected})" mask_equals "${mask}" "${expected}"

	verify_check "irqbalance is not running" not systemctl is-active --quiet irqbalance
	verify_check "kernel.sched_rt_runtime_us = -1" grep -qx -- '-1' /proc/sys/kernel/sched_rt_runtime_us

	# User-space threads on isolated CPUs. Expected: only your pinned application threads.
	for cpu in "${ISOLATED_CPUS[@]}"; do
		stray="$(ps -eLo psr=,pid=,comm= | awk -v c="${cpu}" \
			'$1==c && $3 !~ /^(ksoftirqd|kworker|migration|cpuhp|rcu|watchdog|idle_inject|irq\/|posixcputmr)/ {print $2"("$3")"}' |
			sort -u | tr '\n' ' ')"
		if [[ -n "${stray}" ]]; then
			verify_info "CPU ${cpu} runs: ${stray}"
		fi
	done
	verify_result
}

main() {
	parse_mode_args "$@" || true
	case "${MODE}" in
	apply)
		require_root
		load_config
		apply_cpu_isolation
		;;
	runtime)
		load_config
		apply_cpu_isolation_runtime
		;;
	verify)
		load_config
		verify_cpu_isolation
		;;
	*) print_usage ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
