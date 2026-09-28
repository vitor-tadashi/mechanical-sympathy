#!/usr/bin/env bash
#
# 04-network.sh - NIC queue, coalescing, offload and IRQ placement (Guide 04).
#
#   tune_nic_low_latency <iface> <role> [txqueuelen]  channels, coalescing, pause, offloads, rings
#   set_nic_irq_affinity <iface> <cpu list>           route every IRQ of the NIC to those CPUs
#   show_nic_state <iface>                            one-screen summary of what is configured
#
# Everything here is RUNTIME state: drivers forget it on reboot, link flap or driver
# reload. lowlat-runtime.service re-runs `04-network.sh --runtime` at every boot.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# nic_field <spec> <index> - fields of a NICS entry "name|role|irq_cpus|txqueuelen".
nic_field() {
	local -a fields
	IFS='|' read -r -a fields <<<"$1"
	printf '%s\n' "${fields[$2]:-}"
}

nic_exists() {
	[[ -d "/sys/class/net/$1" ]] && return 0
	# Dry-run on a machine without sysfs (e.g. a laptop): pretend, to show the plan.
	[[ "${DRY_RUN}" -eq 1 && ! -d /sys/class/net ]]
}

# A NIC is "bypass" when a kernel-bypass runtime is installed and the NIC uses its driver.
nic_is_kernel_bypass() {
	local iface="$1" driver
	[[ -n "${KERNEL_BYPASS_DRIVER:-}" && -n "${KERNEL_BYPASS_COMMAND:-}" ]] || return 1
	command -v "${KERNEL_BYPASS_COMMAND}" >/dev/null 2>&1 || return 1
	driver="$({ ethtool -i "${iface}" 2>/dev/null || true; } | awk -F': ' '/^driver:/{print $2}')"
	[[ "${driver}" == "${KERNEL_BYPASS_DRIVER}" ]]
}

# ethtool_max <iface> <-l|-g> <label> - first value of <label> in "Pre-set maximums".
ethtool_max() {
	{ ethtool "$2" "$1" 2>/dev/null || true; } | awk -v l="$3:" '$1==l {print $2; exit}'
}

# tune_nic_low_latency <iface> <role> [txqueuelen]
#   role: critical | timing | bulk | mgmt (mgmt interfaces are never touched)
tune_nic_low_latency() {
	local iface="$1" role="$2" txqueuelen="${3:-0}" usecs=0 combined max_rx max_tx

	if ! nic_exists "${iface}"; then
		log_sub_step "Network interface ${iface} does not exist, skipping"
		return 0
	fi
	if [[ "${role}" == mgmt ]]; then
		log_sub_step "${iface} is a management interface, leaving it untouched"
		return 0
	fi
	[[ "${role}" == bulk ]] && usecs="${NIC_BULK_COALESCE_USECS:-0}"

	# Queues. Kernel bypass: the bypass stack owns the data path, so the kernel needs a
	# single queue (fewer IRQ vectors to place, less memory). Kernel stack: as many
	# queues as the NIC supports, so RSS spreads flows and each queue has its own IRQ.
	if nic_is_kernel_bypass "${iface}"; then
		log_sub_step "${iface}: kernel-bypass NIC, 1 combined queue"
		run_quiet ethtool -L "${iface}" combined 1
	else
		combined="$(ethtool_max "${iface}" -l Combined)"
		if [[ -n "${combined}" && "${combined}" != n/a && "${combined}" -gt 0 ]]; then
			log_sub_step "${iface}: ${combined} combined queues (hardware maximum)"
			run_quiet ethtool -L "${iface}" combined "${combined}"
		fi
		# Adaptive coalescing re-tunes rx/tx-usecs on the fly based on load; with it on,
		# the fixed values below are overwritten within milliseconds.
		log_sub_step "${iface}: adaptive-rx off, adaptive-tx off"
		run_quiet ethtool -C "${iface}" adaptive-rx off adaptive-tx off
	fi

	# Interrupt coalescing: 0 = raise the interrupt as soon as a packet is DMA'd
	# (no waiting to batch more packets into one interrupt).
	log_sub_step "${iface}: rx-usecs ${usecs}, tx-usecs ${usecs}"
	run_quiet ethtool -C "${iface}" rx-usecs "${usecs}"
	run_quiet ethtool -C "${iface}" tx-usecs "${usecs}"

	# Ethernet flow control (IEEE 802.3x PAUSE frames). With it on, a congested peer
	# or switch can pause our transmitter for up to ~3.3 ms at 10G.
	log_sub_step "${iface}: pause frames off (ethtool -A autoneg off rx off tx off)"
	run_quiet ethtool -A "${iface}" autoneg off rx off tx off

	# Segmentation/aggregation offloads batch small packets into large ones (LRO/GRO
	# on receive, TSO/GSO on transmit). Great for throughput, but a small order message
	# may wait for its batch.
	log_sub_step "${iface}: tso off, gso off, lro off"
	run_quiet ethtool -K "${iface}" tso off gso off lro off

	if [[ "${NIC_DISABLE_CSUM_OFFLOAD:-no}" == yes ]]; then
		log_sub_step "${iface}: rx/tx checksum offload off (NIC_DISABLE_CSUM_OFFLOAD=yes)"
		run_quiet ethtool -K "${iface}" rx off tx off
	fi

	# Rings at the hardware maximum: absorbs bursts (market open, reconnect storms)
	# without drops. Latency is not affected when the ring is not backed up.
	max_rx="$(ethtool_max "${iface}" -g RX)"
	max_tx="$(ethtool_max "${iface}" -g TX)"
	if [[ -n "${max_rx}" && "${max_rx}" != n/a ]]; then
		log_sub_step "${iface}: RX ring ${max_rx}"
		run_quiet ethtool -G "${iface}" rx "${max_rx}"
	fi
	if [[ -n "${max_tx}" && "${max_tx}" != n/a ]]; then
		log_sub_step "${iface}: TX ring ${max_tx}"
		run_quiet ethtool -G "${iface}" tx "${max_tx}"
	fi

	if [[ "${txqueuelen}" != 0 ]]; then
		log_sub_step "${iface}: txqueuelen ${txqueuelen}"
		run ip link set dev "${iface}" txqueuelen "${txqueuelen}"
	fi
}

# nic_irqs <iface> - IRQ numbers of the NIC. MSI-X vectors of the PCI function first
# (exact, no name matching); /proc/interrupts names as a fallback (virtio, bonds, ...).
nic_irqs() {
	local iface="$1" dir="/sys/class/net/$1/device/msi_irqs"
	local vector found=0
	if [[ -d "${dir}" ]]; then
		for vector in "${dir}"/*; do
			[[ -e "${vector}" ]] || continue
			printf '%s\n' "${vector##*/}"
			found=1
		done
		[[ "${found}" -eq 1 ]] && return 0
	fi
	# Match "<iface>" or "<iface>-<suffix>" as a whole word (em1 must not match em10).
	awk -v n="${iface}" '{ for (i = NF; i > 1; i--) if ($i == n || index($i, n "-") == 1) { sub(":", "", $1); print $1; break } }' \
		/proc/interrupts
}

# set_nic_irq_affinity <iface> <cpu list> - e.g. set_nic_irq_affinity ens1f0 1
set_nic_irq_affinity() {
	local iface="$1" cpus="$2" irq count=0
	if ! nic_exists "${iface}"; then
		log_sub_step "Network interface ${iface} does not exist, skipping"
		return 0
	fi
	[[ -n "${cpus}" ]] || {
		log_warn "${iface}: no IRQ CPUs configured"
		return 0
	}
	log_sub_step "${iface}: routing interrupts to CPUs ${cpus}"
	while read -r irq; do
		[[ -n "${irq}" && -e "/proc/irq/${irq}/smp_affinity_list" ]] || continue
		if [[ "${DRY_RUN}" -eq 1 ]]; then
			printf '           [dry-run] echo %s > /proc/irq/%s/smp_affinity_list\n' "${cpus}" "${irq}"
		elif ! printf '%s\n' "${cpus}" >"/proc/irq/${irq}/smp_affinity_list" 2>/dev/null; then
			# Kernel-managed IRQs (some drivers on RHEL 9) refuse user placement.
			log_warn "${iface}: IRQ ${irq} is kernel-managed, affinity not changed"
			continue
		fi
		count=$((count + 1))
	done < <(nic_irqs "${iface}")
	log_sub_step "${iface}: ${count} IRQ(s) placed"
}

show_nic_state() {
	local iface="$1" irq
	printf '== %s (%s) numa_node=%s\n' "${iface}" \
		"$(ethtool -i "${iface}" 2>/dev/null | awk -F': ' '/^driver:/{print $2}')" \
		"$(cat "/sys/class/net/${iface}/device/numa_node" 2>/dev/null || echo n/a)"
	ethtool -l "${iface}" 2>/dev/null | awk '/Current/{c=1} c && /Combined/{print "   queues:   " $2; exit}' || true
	ethtool -c "${iface}" 2>/dev/null | awk '/^Adaptive|^rx-usecs:|^tx-usecs:/{printf "   %s", $0; print ""}' || true
	ethtool -a "${iface}" 2>/dev/null | awk '/^(Autonegotiate|RX|TX):/{printf "   pause %s\n", $0}' || true
	ethtool -k "${iface}" 2>/dev/null | awk '/^(tcp-segmentation-offload|generic-segmentation-offload|large-receive-offload|generic-receive-offload|rx-checksumming|tx-checksumming):/{printf "   %s\n", $0}' || true
	ethtool -g "${iface}" 2>/dev/null | awk '/Current/{c=1} c && /^(RX|TX):/{printf "   ring %s\n", $0}' || true
	printf '   txqueuelen: %s\n' "$(cat "/sys/class/net/${iface}/tx_queue_len" 2>/dev/null)"
	while read -r irq; do
		printf '   irq %-5s -> %s\n' "${irq}" "$(cat "/proc/irq/${irq}/smp_affinity_list" 2>/dev/null)"
	done < <(nic_irqs "${iface}")
}

apply_network() {
	local spec iface role cpus txq
	log_step "NIC queues, coalescing, pause frames, offloads and rings"
	if require_capability nic_tuning; then
		require_commands ethtool ip
		for spec in "${NICS[@]}"; do
			iface="$(nic_field "${spec}" 0)"
			role="$(nic_field "${spec}" 1)"
			txq="$(nic_field "${spec}" 3)"
			tune_nic_low_latency "${iface}" "${role}" "${txq:-0}"
		done
	fi

	log_step "NIC interrupt affinity"
	if require_capability nic_irq_affinity; then
		if host_is_vm && systemctl is-active --quiet irqbalance 2>/dev/null; then
			log_warn "irqbalance is running on this VM and will move these IRQs again"
		fi
		for spec in "${NICS[@]}"; do
			iface="$(nic_field "${spec}" 0)"
			role="$(nic_field "${spec}" 1)"
			cpus="$(nic_field "${spec}" 2)"
			[[ "${role}" == mgmt && -z "${cpus}" ]] && continue
			set_nic_irq_affinity "${iface}" "${cpus}"
		done
	fi
}

# --- verification -----------------------------------------------------------

coalesce_is() { # coalesce_is <iface> <key> <value>
	[[ "$(ethtool -c "$1" 2>/dev/null | awk -v k="$2:" '$1==k {print $2; exit}')" == "$3" ]]
}

adaptive_rx_off() {
	ethtool -c "$1" 2>/dev/null | grep -q '^Adaptive RX: off'
}

irqs_on_cpus() { # irqs_on_cpus <iface> <cpu list>
	local irq want actual
	want="$(cpu_list_expand "$2")"
	while read -r irq; do
		actual="$(cat "/proc/irq/${irq}/smp_affinity_list" 2>/dev/null)" || continue
		[[ "$(cpu_list_expand "${actual}")" == "${want}" ]] || return 1
	done < <(nic_irqs "$1")
}

no_nic_irq_on_isolated_cpus() {
	local spec iface irq cpu
	for spec in "${NICS[@]}"; do
		iface="$(nic_field "${spec}" 0)"
		nic_exists "${iface}" || continue
		while read -r irq; do
			for cpu in $(cpu_list_expand "$(cat "/proc/irq/${irq}/effective_affinity_list" 2>/dev/null)"); do
				[[ " ${ISOLATED_CPUS[*]} " == *" ${cpu} "* ]] && return 1
			done
		done < <(nic_irqs "${iface}")
	done
	return 0
}

verify_network() {
	local spec iface role cpus usecs
	for spec in "${NICS[@]}"; do
		iface="$(nic_field "${spec}" 0)"
		role="$(nic_field "${spec}" 1)"
		cpus="$(nic_field "${spec}" 2)"
		if ! nic_exists "${iface}"; then
			verify_info "${iface} (${role}) not present"
			continue
		fi
		[[ "${role}" == mgmt ]] && continue
		usecs=0
		[[ "${role}" == bulk ]] && usecs="${NIC_BULK_COALESCE_USECS:-0}"
		verify_check "${iface} (${role}) rx-usecs=${usecs}" coalesce_is "${iface}" rx-usecs "${usecs}"
		verify_soft "${iface} (${role}) adaptive RX off" adaptive_rx_off "${iface}"
		if [[ -n "${cpus}" ]]; then
			verify_check "${iface} (${role}) IRQs on CPUs ${cpus}" irqs_on_cpus "${iface}" "${cpus}"
		fi
	done
	if host_is_bare_metal; then
		verify_check "no NIC IRQ effective on an isolated CPU" no_nic_irq_on_isolated_cpus
	fi
	verify_result
}

main() {
	parse_mode_args "$@" || true
	case "${MODE}" in
	apply | runtime)
		require_root
		load_config
		apply_network
		;;
	verify)
		load_config
		verify_network
		;;
	*) print_usage ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
