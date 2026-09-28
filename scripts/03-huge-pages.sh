#!/usr/bin/env bash
#
# 03-huge-pages.sh - explicit huge pages reserved per NUMA node at early boot (Guide 03).
#
#   install_hugepage_reservation  generates the per-node reservation script + a oneshot
#                                 unit that runs before dev-hugepages.mount, and enables it
#   reserve_hugepages_now         tries to reserve the same pages immediately (best effort)
#   set_hugepage_sysctls          surplus pages, SysV shm segment limit, hugetlb shm group
#   show_hugepages                per-node pool state
#
# Transparent huge pages are disabled on the kernel command line (Guide 01). Everything
# here is about EXPLICIT (hugetlbfs) pages, which applications must request.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

HUGETLB_RESERVE_SCRIPT="${HUGETLB_RESERVE_SCRIPT:-/usr/lib/systemd/hugetlb-reserve-pages}"
HUGETLB_RESERVE_UNIT="${HUGETLB_RESERVE_UNIT:-/etc/systemd/system/hugetlb-reserve-pages.service}"

# hugepage_size_kb - "2M" -> 2048, "1G" -> 1048576
hugepage_size_kb() {
	case "${HUGEPAGE_SIZE}" in
	2M | 2m | 2048k | 2048K) printf '2048\n' ;;
	1G | 1g | 1024M) printf '1048576\n' ;;
	*) die "unsupported HUGEPAGE_SIZE=${HUGEPAGE_SIZE} (use 2M or 1G)" "${EXIT_PRECHECK}" ;;
	esac
}

# Why a oneshot unit instead of vm.nr_hugepages or hugepages=N on the command line:
#   * hugepages=N (boot) and vm.nr_hugepages split the pool EVENLY across NUMA nodes;
#     we want most pages on the node where the latency-critical threads run.
#   * Reserving right after sysinit, before dev-hugepages.mount and before any service
#     starts, is the moment physical memory is least fragmented, so the reservation of
#     thousands of contiguous 2 MiB blocks succeeds reliably.
install_hugepage_reservation() {
	local size_kb spec node count body=""
	size_kb="$(hugepage_size_kb)"

	for spec in "${HUGEPAGES_PER_NODE[@]}"; do
		node="${spec%%:*}"
		count="${spec##*:}"
		body+="reserve_pages ${count} ${node}"$'\n'
	done

	log_sub_step "Writing per-node reservation script ${HUGETLB_RESERVE_SCRIPT}"
	write_file "${HUGETLB_RESERVE_SCRIPT}" 0755 <<EOF
#!/bin/bash
# Managed by mechanical-sympathy 03-huge-pages.sh - reserves ${HUGEPAGE_SIZE} huge pages per NUMA node.
nodes_path=/sys/devices/system/node
if [[ ! -d \${nodes_path} ]]; then
	echo "ERROR: \${nodes_path} does not exist" >&2
	exit 1
fi

reserve_pages() {
	local wanted="\$1" node="\$2" file got
	file="\${nodes_path}/\${node}/hugepages/hugepages-${size_kb}kB/nr_hugepages"
	if [[ ! -w "\${file}" ]]; then
		echo "WARN: \${file} not writable (node missing?)" >&2
		return 0
	fi
	echo "\${wanted}" >"\${file}"
	got="\$(cat "\${file}")"
	echo "\${node}: requested \${wanted} x ${HUGEPAGE_SIZE}, reserved \${got}"
	[[ "\${got}" -ge "\${wanted}" ]] || echo "WARN: \${node} short by \$((wanted - got)) pages (fragmentation?)" >&2
}

${body}
EOF

	log_sub_step "Writing systemd unit ${HUGETLB_RESERVE_UNIT}"
	write_file "${HUGETLB_RESERVE_UNIT}" 0644 <<EOF
# Managed by mechanical-sympathy 03-huge-pages.sh
[Unit]
Description=Reserve ${HUGEPAGE_SIZE} huge pages per NUMA node
DefaultDependencies=no
Before=dev-hugepages.mount
ConditionPathExists=/sys/devices/system/node
# Only on hosts where Guide 01 set the huge page size on the kernel command line.
ConditionKernelCommandLine=hugepagesz=${HUGEPAGE_SIZE}

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${HUGETLB_RESERVE_SCRIPT}

[Install]
WantedBy=sysinit.target
EOF

	log_sub_step "Enabling hugetlb-reserve-pages.service"
	run systemctl daemon-reload
	run systemctl enable "$(basename "${HUGETLB_RESERVE_UNIT}")"
}

# Best effort: on a host that has been up for a while, memory is fragmented and the
# kernel may give you fewer pages than requested. The boot-time unit is what counts.
reserve_hugepages_now() {
	local size_kb spec node count file
	size_kb="$(hugepage_size_kb)"
	if [[ "${size_kb}" -eq 1048576 ]]; then
		log_sub_step "1G pages can only be reserved reliably at boot; skipping runtime reservation"
		return 0
	fi
	for spec in "${HUGEPAGES_PER_NODE[@]}"; do
		node="${spec%%:*}"
		count="${spec##*:}"
		file="/sys/devices/system/node/${node}/hugepages/hugepages-${size_kb}kB/nr_hugepages"
		log_sub_step "Reserving ${count} x ${HUGEPAGE_SIZE} on ${node} now"
		sysfs_write "${count}" "${file}"
		if [[ "${DRY_RUN}" -ne 1 && -r "${file}" ]]; then
			log_sub_step "${node}: $(cat "${file}") pages reserved"
		fi
	done
}

set_hugepage_sysctls() {
	local gid=""
	gid="$(getent group "${APP_GROUP}" 2>/dev/null | cut -d: -f3 || true)"
	log_sub_step "Writing /etc/sysctl.d/92-lowlat-hugepages.conf"
	write_file /etc/sysctl.d/92-lowlat-hugepages.conf <<EOF
# Managed by mechanical-sympathy 03-huge-pages.sh
# Surplus pages the kernel may allocate on demand once the reserved pool is exhausted.
# Surplus allocation happens at fault time and can fail under fragmentation, so size
# the reserved pool (hugetlb-reserve-pages.service) for the steady state.
vm.nr_overcommit_hugepages = ${HUGEPAGES_OVERCOMMIT}
# Maximum number of System V shared memory segments (IPC libraries, SHM_HUGETLB users).
kernel.shmmni = ${SHMMNI}
${gid:+# Group allowed to create SHM_HUGETLB segments without CAP_IPC_LOCK.
vm.hugetlb_shm_group = ${gid}}
EOF
	run_quiet sysctl -p /etc/sysctl.d/92-lowlat-hugepages.conf
}

show_hugepages() {
	local dir node
	grep -E '^(HugePages_|Hugepagesize|Hugetlb|AnonHugePages)' /proc/meminfo
	for dir in /sys/devices/system/node/node*/hugepages/hugepages-*; do
		[[ -d "${dir}" ]] || continue
		node="$(basename "$(dirname "$(dirname "${dir}")")")"
		printf '%s %s: total=%s free=%s surplus=%s\n' "${node}" "$(basename "${dir}")" \
			"$(cat "${dir}/nr_hugepages")" "$(cat "${dir}/free_hugepages")" "$(cat "${dir}/surplus_hugepages")"
	done
}

node_has_pages() { # node_has_pages <node> <count>
	local file
	file="/sys/devices/system/node/$1/hugepages/hugepages-$(hugepage_size_kb)kB/nr_hugepages"
	[[ -r "${file}" ]] && (($(cat "${file}") >= $2))
}

thp_is_never() {
	grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled
}

apply_huge_pages() {
	log_step "Huge page reservation per NUMA node"
	if require_capability huge_pages; then
		install_hugepage_reservation
		reserve_hugepages_now
	fi

	log_step "Huge page sysctls"
	if require_capability huge_pages; then
		set_hugepage_sysctls
	fi
}

verify_huge_pages() {
	local spec node count line
	verify_check "transparent huge pages disabled ([never])" thp_is_never
	if ! host_is_bare_metal; then
		verify_info "host_class=${HOST_CLASS}: explicit huge pages not expected"
		verify_result
		return
	fi
	verify_check "hugetlb-reserve-pages.service enabled" systemctl is-enabled --quiet hugetlb-reserve-pages.service
	for spec in "${HUGEPAGES_PER_NODE[@]}"; do
		node="${spec%%:*}"
		count="${spec##*:}"
		verify_check "${node} has >= ${count} x ${HUGEPAGE_SIZE} pages reserved" node_has_pages "${node}" "${count}"
	done
	verify_check "vm.nr_overcommit_hugepages = ${HUGEPAGES_OVERCOMMIT}" \
		grep -qx "${HUGEPAGES_OVERCOMMIT}" /proc/sys/vm/nr_overcommit_hugepages
	while read -r line; do verify_info "${line}"; done < <(show_hugepages)
	verify_result
}

rollback_huge_pages() {
	log_step "Removing huge page reservation"
	run_quiet systemctl disable hugetlb-reserve-pages.service
	run rm -f "${HUGETLB_RESERVE_UNIT}" "${HUGETLB_RESERVE_SCRIPT}" /etc/sysctl.d/92-lowlat-hugepages.conf
	run systemctl daemon-reload
	log_sub_step "Releasing reserved pages (pages in use are released when their owner exits)"
	sysfs_write 0 /proc/sys/vm/nr_hugepages
}

main() {
	parse_mode_args "$@" || true
	case "${MODE}" in
	apply)
		require_root
		load_config
		apply_huge_pages
		;;
	verify)
		load_config
		verify_huge_pages
		;;
	rollback)
		require_root
		load_config
		rollback_huge_pages
		;;
	*) print_usage ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
