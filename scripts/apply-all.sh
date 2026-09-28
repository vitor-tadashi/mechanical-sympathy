#!/usr/bin/env bash
#
# apply-all.sh - applies Guides 01-07 in order, or re-applies their runtime part.
#
#   --plan      print what each capability would do on this host class, change nothing
#   --dry-run   print every command and file, change nothing
#   --apply     apply everything and install lowlat-runtime.service (root)
#   --runtime   re-apply only non-persistent state (called at boot by lowlat-runtime.service)
#   --verify    run verify-tuning.sh
#
# Every guide script can also be run on its own; this wrapper only sequences them and
# prints a step-timing summary.

set -Eeuo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=lib/common.sh
. "${SCRIPTS_DIR}/lib/common.sh"
# shellcheck source=01-grub-bootloader.sh
. "${SCRIPTS_DIR}/01-grub-bootloader.sh"
# shellcheck source=02-cpu-isolation.sh
. "${SCRIPTS_DIR}/02-cpu-isolation.sh"
# shellcheck source=03-huge-pages.sh
. "${SCRIPTS_DIR}/03-huge-pages.sh"
# shellcheck source=04-network.sh
. "${SCRIPTS_DIR}/04-network.sh"
# shellcheck source=05-cgroup-isolation.sh
. "${SCRIPTS_DIR}/05-cgroup-isolation.sh"
# shellcheck source=06-kernel-sysctl.sh
. "${SCRIPTS_DIR}/06-kernel-sysctl.sh"
# shellcheck source=07-os-hygiene.sh
. "${SCRIPTS_DIR}/07-os-hygiene.sh"

RUNTIME_UNIT=/etc/systemd/system/lowlat-runtime.service

print_header() {
	printf 'LOW-LATENCY TUNING (%s)\n' "$1"
	printf '  os:         %s\n' "$(awk -F= '$1=="PRETTY_NAME"{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null || uname -s)"
	printf '  kernel:     %s\n' "$(uname -r)"
	printf '  host class: %s\n' "${HOST_CLASS}"
	printf '  config:     %s\n' "${LOWLAT_CONFIG}"
	printf '  date:       %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
	[[ "${DRY_RUN}" -eq 1 ]] && printf '  mode:       DRY-RUN (nothing is changed)\n'
	return 0
}

print_plan() {
	local capability
	printf 'host_class=%s\n' "${HOST_CLASS}"
	for capability in latency_grub isolation_grub core_isolation irqbalance_disable rt_throttling \
		huge_pages sysctl os_hygiene cgroup_isolation nic_tuning nic_irq_affinity; do
		printf '%-20s %s\n' "${capability}" "$(capability_decision "${capability}")"
	done
	printf '%-20s %s\n' flush_firewall "${FLUSH_FIREWALL_RULES:-no}"
	printf '%-20s %s\n' remove_netfilter "${REMOVE_NETFILTER_MODULES:-no}"
}

install_runtime_unit() {
	LOWLAT_CONFIG="$(cd "$(dirname "${LOWLAT_CONFIG}")" && pwd -P)/$(basename "${LOWLAT_CONFIG}")"
	log_sub_step "Installing ${RUNTIME_UNIT} (ExecStart=${SCRIPTS_DIR}/apply-all.sh --runtime)"
	sed "s|^ExecStart=.*|ExecStart=${SCRIPTS_DIR}/apply-all.sh --runtime|; s|^Environment=LOWLAT_CONFIG=.*|Environment=LOWLAT_CONFIG=${LOWLAT_CONFIG}|; s|^ConditionPathExists=.*|ConditionPathExists=${LOWLAT_CONFIG}|" \
		"${SCRIPTS_DIR}/systemd/lowlat-runtime.service" | write_file "${RUNTIME_UNIT}"
	run systemctl daemon-reload
	run systemctl enable lowlat-runtime.service
}

apply_all() {
	print_header apply
	apply_grub_kernel_parameters        # 01 (reboot)
	apply_cpu_isolation                 # 02 (reboot for systemd CPUAffinity)
	apply_huge_pages                    # 03 (reboot for reliable reservation)
	apply_kernel_sysctl                 # 06
	apply_os_hygiene                    # 07 (tuned re-applies sysctl.d after its own)
	apply_cgroup_isolation              # 05
	apply_network                       # 04 (runtime)
	log_step "Boot-time re-application of runtime settings"
	install_runtime_unit
	print_step_timing_table
	printf '\nReboot required for GRUB, systemd CPUAffinity and huge page reservation.\n'
	printf 'After the reboot: %s/verify-tuning.sh\n' "${SCRIPTS_DIR}"
}

apply_all_runtime() {
	print_header runtime
	apply_cpu_isolation_runtime         # 02 workqueue mask
	apply_network                       # 04 NIC settings + IRQ affinity
	apply_cgroup_isolation_runtime      # 05 pin agents
	apply_os_hygiene_runtime            # 07 opt-in firewall / modules
	print_step_timing_table
}

apply_all_main() {
	if [[ "${1:-}" == --plan ]]; then
		shift
		parse_mode_args "$@" || true
		MODE=plan
	else
		parse_mode_args "$@" || true
	fi
	case "${MODE}" in
	plan)
		load_config
		print_plan
		;;
	apply)
		require_root
		load_config
		host_allows_apply || die "host_class=${HOST_CLASS} is not supported for tuning" "${EXIT_PRECHECK}"
		apply_all
		;;
	runtime)
		require_root
		load_config
		apply_all_runtime
		;;
	verify)
		exec "${SCRIPTS_DIR}/verify-tuning.sh" "$@"
		;;
	*)
		print_usage
		printf '  --plan       show the capability decisions for this host class\n'
		;;
	esac
}

apply_all_main "$@"
