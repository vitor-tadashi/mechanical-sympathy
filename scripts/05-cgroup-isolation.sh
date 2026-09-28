#!/usr/bin/env bash
#
# 05-cgroup-isolation.sh - fence non-critical processes (Guide 05).
#
#   create_housekeeping_slice        housekeeping.slice with CPU/memory/IO limits
#   move_service_to_slice <unit>     drop-in: Slice=housekeeping.slice + CPUAffinity
#   pin_housekeeping_processes       taskset agents that are not systemd units (runtime)
#   cgroup_version                   prints 1 or 2
#
# systemd CPUAffinity (Guide 02) already keeps every service off the isolated CPUs.
# This guide adds two things on top: a HARD fence for processes that reset their own
# affinity (security agents often do), and resource limits so a misbehaving agent
# cannot exhaust memory, I/O or the housekeeping CPUs the kernel and NIC IRQs need.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

HOUSEKEEPING_SLICE="${HOUSEKEEPING_SLICE:-housekeeping.slice}"
SYSTEMD_UNIT_DIR="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"

cgroup_version() {
	if [[ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" == cgroup2fs ]]; then
		printf '2\n'
	else
		printf '1\n'
	fi
}

create_housekeeping_slice() {
	local version cpus
	version="$(cgroup_version)"
	cpus="${HOUSEKEEPING_SLICE_CPUS[*]}"

	log_sub_step "Writing ${SYSTEMD_UNIT_DIR}/${HOUSEKEEPING_SLICE} (cgroup v${version})"
	if [[ "${version}" -eq 2 ]]; then
		write_file "${SYSTEMD_UNIT_DIR}/${HOUSEKEEPING_SLICE}" <<EOF
# Managed by mechanical-sympathy 05-cgroup-isolation.sh
[Unit]
Description=Housekeeping processes (agents, log shippers, monitoring)
Before=slices.target

[Slice]
# cpuset: a hard fence. Processes in this slice cannot run elsewhere, even if they
# call sched_setaffinity() themselves.
AllowedCPUs=${cpus}
# At most ${HOUSEKEEPING_SLICE_CPU_QUOTA} of one CPU in total, across the whole slice.
CPUQuota=${HOUSEKEEPING_SLICE_CPU_QUOTA}
# Hard memory cap: exceeding it triggers the OOM killer inside this slice only,
# never on the application. No swap for these processes either.
MemoryMax=${HOUSEKEEPING_SLICE_MEMORY_MAX}
MemorySwapMax=0
# Relative I/O share (default 100): agents yield to everything else on contention.
IOWeight=${HOUSEKEEPING_SLICE_IO_WEIGHT}
EOF
	else
		write_file "${SYSTEMD_UNIT_DIR}/${HOUSEKEEPING_SLICE}" <<EOF
# Managed by mechanical-sympathy 05-cgroup-isolation.sh (cgroup v1: no AllowedCPUs,
# CPU placement is done with CPUAffinity= in each unit's drop-in)
[Unit]
Description=Housekeeping processes (agents, log shippers, monitoring)
Before=slices.target

[Slice]
CPUQuota=${HOUSEKEEPING_SLICE_CPU_QUOTA}
MemoryLimit=${HOUSEKEEPING_SLICE_MEMORY_MAX}
BlockIOWeight=${HOUSEKEEPING_SLICE_IO_WEIGHT}
EOF
	fi
	run systemctl daemon-reload
}

# move_service_to_slice <unit> - puts an existing service into the housekeeping slice.
move_service_to_slice() {
	local unit="$1" dropin
	if ! systemctl cat "${unit}" >/dev/null 2>&1 && [[ "${DRY_RUN}" -ne 1 ]]; then
		log_sub_step "${unit} is not installed, skipping"
		return 0
	fi
	dropin="${SYSTEMD_UNIT_DIR}/${unit}.d/10-lowlat-housekeeping.conf"
	log_sub_step "Moving ${unit} into ${HOUSEKEEPING_SLICE}"
	write_file "${dropin}" <<EOF
# Managed by mechanical-sympathy 05-cgroup-isolation.sh
[Service]
Slice=${HOUSEKEEPING_SLICE}
CPUAffinity=${HOUSEKEEPING_SLICE_CPUS[*]}
Nice=10
IOSchedulingClass=idle
EOF
}

# pin_housekeeping_processes - for agents NOT started by systemd (vendor init scripts,
# watchdogs that respawn children) or that reset their own affinity on cgroup v1.
# Pins every thread of every matching process to HOUSEKEEPING_PIN_CPUS.
pin_housekeeping_processes() {
	local cpu_list proc pid found
	cpu_list="$(cpu_list_join "${HOUSEKEEPING_PIN_CPUS[@]}")"
	for proc in "${HOUSEKEEPING_PIN_PROCESSES[@]}"; do
		found=0
		while IFS= read -r pid; do
			[[ -n "${pid}" ]] || continue
			found=1
			log_sub_step "Pinning ${proc} pid ${pid} (all threads) to CPUs ${cpu_list}"
			run_quiet taskset -a -cp "${cpu_list}" "${pid}"
		done < <(pgrep -x "${proc}" 2>/dev/null || true)
		if [[ "${found}" -eq 0 ]]; then
			log_sub_step "${proc} is not running"
		fi
	done
}

apply_cgroup_isolation() {
	local unit
	log_step "Housekeeping slice"
	if require_capability cgroup_isolation; then
		create_housekeeping_slice
	fi

	log_step "Moving agent services into the housekeeping slice"
	if require_capability cgroup_isolation; then
		for unit in "${HOUSEKEEPING_SLICE_UNITS[@]}"; do
			move_service_to_slice "${unit}"
		done
		run systemctl daemon-reload
		log_sub_step "Restart the moved services (or reboot) for the new slice to take effect"
	fi

	log_step "Pinning housekeeping processes"
	if require_capability cgroup_isolation; then
		pin_housekeeping_processes
	fi
}

apply_cgroup_isolation_runtime() {
	log_step "Pinning housekeeping processes"
	pin_housekeeping_processes
}

# --- verification -----------------------------------------------------------

unit_in_slice() { # unit_in_slice <unit>
	[[ "$(systemctl show -p Slice --value "$1" 2>/dev/null)" == "${HOUSEKEEPING_SLICE}" ]]
}

pid_on_cpus() { # pid_on_cpus <pid> <cpu>...
	local pid="$1" actual
	shift
	actual="$(awk -F'\t' '/^Cpus_allowed_list/{print $2}' "/proc/${pid}/status" 2>/dev/null)"
	[[ "$(cpu_list_expand "${actual}")" == "$*" ]]
}

verify_cgroup_isolation() {
	local unit proc pid
	verify_info "cgroup version: v$(cgroup_version)"
	verify_check "${HOUSEKEEPING_SLICE} exists" test -f "${SYSTEMD_UNIT_DIR}/${HOUSEKEEPING_SLICE}"
	for unit in "${HOUSEKEEPING_SLICE_UNITS[@]}"; do
		if systemctl cat "${unit}" >/dev/null 2>&1; then
			verify_check "${unit} runs in ${HOUSEKEEPING_SLICE}" unit_in_slice "${unit}"
		else
			verify_info "${unit} not installed"
		fi
	done
	for proc in "${HOUSEKEEPING_PIN_PROCESSES[@]}"; do
		while IFS= read -r pid; do
			[[ -n "${pid}" ]] || continue
			verify_check "${proc} (${pid}) pinned to ${HOUSEKEEPING_PIN_CPUS[*]}" pid_on_cpus "${pid}" "${HOUSEKEEPING_PIN_CPUS[@]}"
		done < <(pgrep -x "${proc}" 2>/dev/null || true)
	done
	if [[ "$(cgroup_version)" -eq 2 && -r "/sys/fs/cgroup/${HOUSEKEEPING_SLICE}/cpuset.cpus.effective" ]]; then
		verify_info "${HOUSEKEEPING_SLICE} cpuset.cpus.effective = $(cat "/sys/fs/cgroup/${HOUSEKEEPING_SLICE}/cpuset.cpus.effective")"
	fi
	verify_result
}

rollback_cgroup_isolation() {
	local unit
	log_step "Removing housekeeping slice and drop-ins"
	for unit in "${HOUSEKEEPING_SLICE_UNITS[@]}"; do
		run rm -f "${SYSTEMD_UNIT_DIR}/${unit}.d/10-lowlat-housekeeping.conf"
	done
	run rm -f "${SYSTEMD_UNIT_DIR}/${HOUSEKEEPING_SLICE}"
	run systemctl daemon-reload
	log_sub_step "Restart the affected services to move them back to system.slice"
}

main() {
	parse_mode_args "$@" || true
	case "${MODE}" in
	apply)
		require_root
		load_config
		apply_cgroup_isolation
		;;
	runtime)
		require_root
		load_config
		apply_cgroup_isolation_runtime
		;;
	verify)
		load_config
		verify_cgroup_isolation
		;;
	rollback)
		require_root
		load_config
		rollback_cgroup_isolation
		;;
	*) print_usage ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
