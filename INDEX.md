# Index

## Reading paths

**Operator applying the tuning (1–2 h plus a reboot)**
[QUICK_START](QUICK_START.md) → [01](guides/01-grub-bootloader-tuning.md) → [02](guides/02-cpu-core-isolation.md) → [03](guides/03-huge-pages-configuration.md) → [04](guides/04-network-optimization.md) → [05](guides/05-cgroup-isolation.md) → [06](guides/06-kernel-sysctl-tuning.md) → [07](guides/07-os-hygiene.md) → `scripts/verify-tuning`

**Application developer (how my code should behave on a tuned host)**
[Guide 02 §6 — pinning the application](guides/02-cpu-core-isolation.md#6-pinning-the-application) → [Guide 03 §5 — Java flags](guides/03-huge-pages-configuration.md#5-java-applications) → [Java example](examples/hugepages-java-example.md) → [concepts/cpu-isolation §5 — caches and coherence](concepts/cpu-isolation.md#5-caches-and-coherence-the-mechanical-sympathy-part)

**Engineering manager / reviewer (what, why, and what can go wrong)**
[README — Read this first](README.md#read-this-first) → risk and applicability tables at the top of each guide → [Guide 01 §5.6 — mitigations](guides/01-grub-bootloader-tuning.md#56-iommu-and-cpu-vulnerability-mitigations-security-sensitive) → [Guide 07 §6 — firewall](guides/07-os-hygiene.md#6-opt-in-removing-host-packet-filtering)

**Network engineer**
[Guide 04](guides/04-network-optimization.md) → [concepts/network-tuning](concepts/network-tuning.md) → [segmentation example](examples/network-segmentation-example.md) → [Guide 06 §3–6](guides/06-kernel-sysctl-tuning.md#3-tcp-behaviour)

## Guides

| Guide | Covers | Key functions |
|---|---|---|
| [01 Kernel command line](guides/01-grub-bootloader-tuning.md) | isolcpus, nohz_full, rcu_nocbs, idle/C-states, THP, huge page size, watchdogs, IOMMU, mitigations | `apply_grub_kernel_parameters`, `rollback_grub_kernel_parameters` |
| [02 CPU isolation](guides/02-cpu-core-isolation.md) | CPU layout, systemd CPUAffinity, workqueues, irqbalance, RT throttling, thread pinning, idle strategies | `configure_systemd_cpu_affinity`, `set_workqueue_affinity`, `pin_process`, `show_affinity` |
| [03 Huge pages](guides/03-huge-pages-configuration.md) | THP vs explicit, sizing, per-NUMA early-boot reservation, Java flags, C/C++ mmap, 1 GiB pages | `install_hugepage_reservation`, `set_hugepage_sysctls`, `show_hugepages` |
| [04 Network](guides/04-network-optimization.md) | NIC roles, channels, coalescing, pause, offloads, rings, txqueuelen, IRQ affinity, RPS/XPS, kernel bypass, persistence | `tune_nic_low_latency`, `set_nic_irq_affinity`, `show_nic_state` |
| [05 cgroups](guides/05-cgroup-isolation.md) | v1/v2, housekeeping slice, agent pinning, cpuset trap, app unit template, cpuset partitions | `create_housekeeping_slice`, `move_service_to_slice`, `pin_housekeeping_processes` |
| [06 sysctl](guides/06-kernel-sysctl-tuning.md) | logging, TCP, buffers, queues, IPv6/ARP, BPF, VM | `write_sysctl_profile`, `apply_sysctl_profile` |
| [07 OS hygiene](guides/07-os-hygiene.md) | services, limits, noatime, tuned, opt-in firewall/netfilter | `disable_unnecessary_services`, `set_security_limits`, `install_tuned_profile` |

## Concepts

| Concept | Questions it answers |
|---|---|
| [Boot path](concepts/bootloader.md) | How do arguments reach the kernel? What is the housekeeping mask? Why can't these be changed at runtime? |
| [CPU isolation](concepts/cpu-isolation.md) | What interrupts a CPU? What does a context switch really cost? Spin or block? |
| [Network path](concepts/network-tuning.md) | Where does a packet wait between the wire and `recv()`? What do coalescing, NAPI, RSS, and bypass change? |
| [Huge pages & NUMA](concepts/huge-pages.md) | What is TLB reach? Why pre-touch? Why is THP unpredictable? Why reserve per node? |
| [cgroups](concepts/cgroups.md) | Affinity vs cpuset? What do quota, memory.max, io.weight do? How does systemd map onto cgroups? |

## Examples

| Example | Shows |
|---|---|
| [Java on a tuned host](examples/hugepages-java-example.md) + [code](examples/java-latency-probe/) | Launcher by host class, large pages + NUMA + pre-touch when pinned, thread roles → CPUs, padded single-writer sequences, RTT and TLB-walk histograms |
| [Multi-NIC segmentation](examples/network-segmentation-example.md) | Six NIC roles, routing with one default route, IRQ/CPU map, qdisc per role, `tc` prioritisation on a shared NIC, PTP, persistence matrix |

## Scripts

| Script | Use |
|---|---|
| [`lowlat.conf.example`](scripts/lowlat.conf.example) | Describe the host. Copy to `/etc/lowlat/lowlat.conf`. |
| `0N-* --dry-run / --apply / --verify / --rollback` | One guide at a time |
| [`apply-all`](scripts/apply-all) `--plan / --dry-run / --apply / --runtime` | All guides in order, with step timing |
| [`verify-tuning`](scripts/verify-tuning) `[--report FILE]` | Read-only PASS/WARN/FAIL for everything |
| [`systemd/lowlat-runtime.service`](scripts/systemd/lowlat-runtime.service) | Re-applies runtime state at boot |

## Glossary

| Term | Meaning |
|---|---|
| Isolated CPU | Removed from scheduler load balancing (`isolcpus`), tickless (`nohz_full`), and RCU-offloaded (`rcu_nocbs`). Runs only explicitly pinned threads. |
| Housekeeping CPU | Non-isolated CPU that runs the OS, kernel threads, and interrupts |
| OS CPUs | All non-isolated CPUs. systemd's `CPUAffinity`. |
| Tick | Periodic scheduler timer interrupt (`CONFIG_HZ`) |
| Coalescing | NIC delaying interrupts to batch packets |
| NAPI | Linux's interrupt-then-poll receive mechanism |
| THP | Transparent Huge Pages (kernel-managed, disabled here) |
| hugetlbfs | Explicit, pre-reserved huge pages |
| TLB reach | Memory covered by the TLB: entries × page size |
| First touch | Default NUMA policy: a page is allocated on the node of the CPU that first writes it |
| Slice | systemd unit that is a node in the cgroup tree |
| Kernel bypass | User-space NIC access that avoids interrupts, syscalls, and the kernel stack |
