#!/usr/bin/env bash
#
# verify-tuning.sh - read-only report of every tuning guide (01-07) on this host.
#
#   verify-tuning.sh [--config FILE] [--report FILE]
#
# Exit status: 0 = no FAIL (warnings allowed), 5 = at least one FAIL.
# Does not need root, but some checks (IRQ affinity of other users' processes, tuned)
# show more detail when run as root.

set -Eeuo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

REPORT_FILE=""
ARGS=()
while (($# > 0)); do
	case "$1" in
	--report)
		shift
		REPORT_FILE="$1"
		;;
	--verify) ;;
	*) ARGS+=("$1") ;;
	esac
	shift
done

if [[ -n "${REPORT_FILE}" ]]; then
	exec > >(tee "${REPORT_FILE}") 2>&1
fi

# shellcheck source=lib/common.sh
. "${SCRIPTS_DIR}/lib/common.sh"
for guide in 01-grub-bootloader 02-cpu-isolation 03-huge-pages 04-network 05-cgroup-isolation 06-kernel-sysctl 07-os-hygiene; do
	# shellcheck source=/dev/null
	. "${SCRIPTS_DIR}/${guide}.sh"
done

parse_mode_args --verify "${ARGS[@]}" || true
load_config

section() {
	printf '\n%s== %s ==%s\n' "${BOLD}" "$1" "${RESET}"
}

# --- host-wide checks that do not belong to a single guide -------------------

cpu_governor_is_performance() {
	local f
	for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
		[[ -r "${f}" ]] || return 0 # no cpufreq (VM): nothing to check
		[[ "$(cat "${f}")" == performance ]] || return 1
	done
}

no_deep_cstate_usage() {
	# With idle=poll there is no cpuidle driver; otherwise states deeper than C1 must be disabled or unused.
	[[ "$(cat /sys/devices/system/cpu/cpuidle/current_driver 2>/dev/null || echo none)" == none ]]
}

swap_off_or_unused() {
	[[ "$(awk '/^SwapTotal/{t=$2} /^SwapFree/{f=$2} END{print t-f}' /proc/meminfo)" -eq 0 ]]
}

clocksource_is_tsc() {
	grep -qx tsc /sys/devices/system/clocksource/clocksource0/current_clocksource
}

time_synchronized() {
	timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qx yes ||
		chronyc tracking 2>/dev/null | grep -q 'Leap status *: Normal'
}

verify_host_wide() {
	verify_soft "CPU frequency governor is performance on every CPU" cpu_governor_is_performance
	verify_soft "no cpuidle driver active (idle=poll)" no_deep_cstate_usage
	verify_soft "clocksource is tsc (cheap, vDSO-accelerated clock_gettime)" clocksource_is_tsc
	verify_soft "no swap in use" swap_off_or_unused
	verify_soft "clock synchronized (chrony/PTP)" time_synchronized
	verify_info "vulnerability mitigations: $(grep -l -v -i '^not affected' /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')"
	verify_info "load average: $(cut -d' ' -f1-3 /proc/loadavg), uptime: $(uptime -p 2>/dev/null || true)"
}

# --- report --------------------------------------------------------------------

printf '%sLOW-LATENCY TUNING VERIFICATION%s\n' "${BOLD}" "${RESET}"
printf '  host:       %s\n' "$(hostname -s 2>/dev/null || hostname)"
printf '  kernel:     %s\n' "$(uname -r)"
printf '  host class: %s\n' "${HOST_CLASS}"
printf '  config:     %s\n' "${LOWLAT_CONFIG}"
printf '  date:       %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

# Each verify_* function uses the shared VERIFY_FAILURES / VERIFY_WARNINGS counters and
# returns non-zero on failures; we keep going and summarise at the end.
section "01 Kernel command line"
verify_grub_kernel_parameters || true
section "02 CPU isolation"
verify_cpu_isolation || true
section "03 Huge pages"
verify_huge_pages || true
section "04 Network"
verify_network || true
section "05 cgroup isolation"
verify_cgroup_isolation || true
section "06 Kernel sysctl"
verify_kernel_sysctl || true
section "07 OS hygiene"
verify_os_hygiene || true
section "Host-wide"
verify_host_wide

section "Summary"
if ((VERIFY_FAILURES == 0 && VERIFY_WARNINGS == 0)); then
	printf '  %sALL CHECKS PASSED%s\n' "${GREEN}" "${RESET}"
elif ((VERIFY_FAILURES == 0)); then
	printf '  %sPASSED WITH %d WARNING(S)%s\n' "${YELLOW}" "${VERIFY_WARNINGS}" "${RESET}"
else
	printf '  %s%d FAILURE(S), %d WARNING(S)%s\n' "${RED}" "${VERIFY_FAILURES}" "${VERIFY_WARNINGS}" "${RESET}"
fi
cat <<'EOF'

  Configuration verified is not latency verified. Next steps:
    * noise on an isolated CPU:   rtla osnoise top -c <cpu> -d 60s
    * per-thread context switches: perf stat -e context-switches,cpu-migrations -t <tid> -- sleep 30
    * end-to-end:                 compare p50/p99/p99.9/max with the baseline taken before tuning
EOF

((VERIFY_FAILURES == 0)) || exit "${EXIT_VERIFY}"
