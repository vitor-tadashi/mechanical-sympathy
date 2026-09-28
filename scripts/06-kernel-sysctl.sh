#!/usr/bin/env bash
#
# 06-kernel-sysctl.sh - kernel runtime parameters (Guide 06).
#
#   write_sysctl_profile   generates /etc/sysctl.d/90-lowlat.conf (persistent)
#   apply_sysctl_profile   loads it now (sysctl -p)
#
# Keys that do not exist on the running kernel (e.g. net.ipv4.tcp_shrink_window on
# RHEL 8/9) are left out of the file and reported, instead of failing silently.
# /etc/sysctl.conf is never modified.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SYSCTL_PROFILE="${SYSCTL_PROFILE:-/etc/sysctl.d/90-lowlat.conf}"

# key|value|why - one line per parameter; "#" lines become section headers.
sysctl_table() {
	cat <<'EOF'
# Kernel logging and debug
kernel.printk|1 4 1 7|console loglevel 1: only emergencies are printed synchronously on the console
kernel.nmi_watchdog|0|no periodic perf NMI on every CPU (also nmi_watchdog=0 on the command line)
debug.exception-trace|0|do not log every user-space segfault/trap to the kernel log
kernel.ftrace_enabled|0|disable function tracer hooks (re-enable temporarily when you need ftrace)
kernel.numa_balancing|0|no automatic NUMA page migration: memory placement is decided by pinning + huge pages
# TCP behaviour
net.ipv4.tcp_timestamps|1|keep RFC 7323 timestamps: required by tcp_tw_reuse and PAWS, improves RTT estimation
net.ipv4.tcp_sack|1|selective ACKs: recover several lost segments in one round trip
net.ipv4.tcp_window_scaling|1|receive windows above 64 KiB (needed for the buffer sizes below)
net.ipv4.tcp_slow_start_after_idle|0|do not collapse cwnd after idle: the first order after a quiet period is not throttled
net.ipv4.tcp_fastopen|3|TFO for client and server: data in the SYN on reconnect
net.ipv4.tcp_fin_timeout|5|FIN_WAIT_2 orphan timeout (seconds); frees half-closed sockets quickly
net.ipv4.tcp_tw_reuse|1|reuse TIME_WAIT sockets for NEW OUTGOING connections (safe with timestamps)
net.ipv4.tcp_max_tw_buckets|262144|room for TIME_WAIT sockets on busy gateways
net.ipv4.tcp_max_orphans|32768|orphaned sockets allowed before the kernel resets them
net.ipv4.tcp_syn_retries|1|fail a connect() after ~3 s instead of ~127 s: fail over to the backup peer fast
net.ipv4.tcp_syncookies|1|keep SYN-flood protection on
net.ipv4.tcp_abort_on_overflow|0|drop (do not RST) when the accept queue is full; clients retry
net.core.somaxconn|2048|accept queue length limit
net.ipv4.tcp_max_syn_backlog|2048|half-open connection queue
net.ipv4.tcp_keepalive_time|120|start keepalive probes after 2 min idle
net.ipv4.tcp_keepalive_intvl|15|probe every 15 s
net.ipv4.tcp_keepalive_probes|5|declare the peer dead after 5 probes (~3 min total)
net.ipv4.tcp_moderate_rcvbuf|1|receive buffer auto-tuning within tcp_rmem
net.ipv4.tcp_no_metrics_save|0|keep per-destination metrics (RTT, cwnd) between connections
net.ipv4.tcp_shrink_window|0|never shrink the advertised window (kernel >= 6.5 only)
# Socket buffers (128 MiB ceilings: large enough for IPC/messaging windows)
net.core.rmem_max|134217728|max SO_RCVBUF an application may request
net.core.wmem_max|134217728|max SO_SNDBUF an application may request
net.core.rmem_default|8388608|default receive buffer (UDP sockets that never call setsockopt)
net.core.wmem_default|8388608|default send buffer
net.core.optmem_max|134217728|ancillary buffer (timestamps, cmsg) per socket
net.ipv4.tcp_rmem|4096 8388608 134217728|TCP receive min/default/max
net.ipv4.tcp_wmem|4096 8388608 134217728|TCP send min/default/max
# Queues
net.core.netdev_max_backlog|300000|per-CPU RX backlog between driver and stack (not related to txqueuelen)
net.core.default_qdisc|fq_codel|default qdisc for new interfaces (RHEL default; bulk NICs benefit from AQM)
net.core.txrehash|1|re-hash TX queue selection on retransmit (kernel >= 5.18 only)
# Routing / forwarding (this host is an endpoint, not a router)
net.ipv4.ip_forward|0|do not route between interfaces
net.ipv6.conf.all.forwarding|0|same for IPv6
# BPF
net.core.bpf_jit_enable|1|JIT-compile BPF (socket filters, tc, tracing) instead of interpreting it
net.core.bpf_jit_limit|528482304|memory allowed for JIT-compiled BPF programs
# Virtual memory
vm.dirty_ratio|10|synchronous writeback throttling starts at 10% dirty memory
vm.dirty_background_ratio|3|background writeback starts at 3%: small, frequent flushes instead of big bursts
vm.min_free_kbytes|1048576|keep 1 GiB free: kswapd starts earlier, allocations rarely hit direct reclaim
vm.stat_interval|60|fold per-CPU VM statistics every 60 s instead of 1 s (fewer kworker wake-ups)
fs.file-max|13076444|system-wide open file limit
EOF
}

sysctl_key_exists() {
	local path="/proc/sys/${1//./\/}"
	[[ -e "${path}" ]] && return 0
	# dry-run on a non-Linux machine: keep everything in the preview
	[[ "${DRY_RUN}" -eq 1 && ! -d /proc/sys ]]
}

# Per-interface keys generated from NICS (IPv6 off, strict ARP on multi-homed hosts).
per_interface_lines() {
	local spec iface
	printf '\n# IPv6 disabled (IPv4-only host; avoids RA/ND/MLD traffic and timers)\n'
	for iface in all default lo; do
		printf 'net.ipv6.conf.%s.disable_ipv6 = 1\n' "${iface}"
	done
	for spec in "${NICS[@]}"; do
		iface="${spec%%|*}"
		printf 'net.ipv6.conf.%s.disable_ipv6 = 1\n' "${iface}"
	done
	printf '\n# ARP on a multi-homed host: only answer for addresses configured on the receiving interface\n'
	for iface in lo "${NICS[@]%%|*}"; do
		printf 'net.ipv4.conf.%s.arp_ignore = 1\n' "${iface}"
		printf 'net.ipv4.conf.%s.arp_announce = 0\n' "${iface}"
		printf 'net.ipv4.conf.%s.arp_filter = 0\n' "${iface}"
		printf 'net.ipv4.conf.%s.arp_accept = 0\n' "${iface}"
	done
}

write_sysctl_profile() {
	local line key value why content skipped=()
	content="# Managed by mechanical-sympathy 06-kernel-sysctl.sh - see guides/06-kernel-sysctl-tuning.md"$'\n'
	while IFS= read -r line; do
		if [[ "${line}" == \#* ]]; then
			content+=$'\n'"${line}"$'\n'
			continue
		fi
		IFS='|' read -r key value why <<<"${line}"
		if ! sysctl_key_exists "${key}"; then
			skipped+=("${key}")
			continue
		fi
		content+="# ${why}"$'\n'"${key} = ${value}"$'\n'
	done < <(sysctl_table)
	content+="$(per_interface_lines)"

	if ((${#skipped[@]} > 0)); then
		log_sub_step "Not available on kernel $(uname -r), skipped: ${skipped[*]}"
	fi
	log_sub_step "Writing ${SYSCTL_PROFILE}"
	printf '%s\n' "${content}" | write_file "${SYSCTL_PROFILE}"
}

apply_sysctl_profile() {
	log_sub_step "Loading ${SYSCTL_PROFILE} (per-interface keys for absent interfaces may warn)"
	run_quiet sysctl -p "${SYSCTL_PROFILE}"
}

apply_kernel_sysctl() {
	log_step "Kernel sysctl profile"
	if require_capability sysctl; then
		write_sysctl_profile
		apply_sysctl_profile
	fi
}

sysctl_is() { # sysctl_is <key> <value>
	local actual
	actual="$(sysctl -n "$1" 2>/dev/null | tr -s '[:space:]' ' ')"
	[[ "${actual% }" == "$2" ]]
}

verify_kernel_sysctl() {
	local line key value why
	verify_check "${SYSCTL_PROFILE} exists" test -f "${SYSCTL_PROFILE}"
	while IFS= read -r line; do
		[[ "${line}" == \#* ]] && continue
		IFS='|' read -r key value why <<<"${line}"
		if [[ -e "/proc/sys/${key//./\/}" ]]; then
			verify_check "${key} = ${value}" sysctl_is "${key}" "${value}"
		fi
	done < <(sysctl_table)
	verify_result
}

main() {
	parse_mode_args "$@" || true
	case "${MODE}" in
	apply)
		require_root
		load_config
		apply_kernel_sysctl
		;;
	verify)
		load_config
		verify_kernel_sysctl
		;;
	rollback)
		require_root
		log_step "Removing ${SYSCTL_PROFILE}"
		run rm -f "${SYSCTL_PROFILE}"
		log_sub_step "Values stay active until reboot (or re-run: sysctl --system)"
		;;
	*) print_usage ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
