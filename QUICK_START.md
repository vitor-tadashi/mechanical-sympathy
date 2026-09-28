# Quick Start — Pick Your Scenario

Before anything else, capture a **baseline**: latency percentiles (p50/p99/p99.9/max) of your real workload, or of the [probe](examples/hugepages-java-example.md), plus `scripts/verify-tuning --report baseline.txt`. Without a baseline you cannot tell whether tuning helped.

---

## Scenario A: Dedicated bare-metal host (the full treatment)

**For:** one latency-critical application (plus its sidecars) on its own physical server, with threads that can be pinned.

| Step | Guide | What you do | Reboot |
|---|---|---|---|
| 1 | — | Design the CPU layout: NIC NUMA node, isolated CPUs, housekeeping CPUs ([Guide 02 §3](guides/02-cpu-core-isolation.md#3-designing-the-cpu-layout)) and write `/etc/lowlat/lowlat.conf` | |
| 2 | [01](guides/01-grub-bootloader-tuning.md) | Kernel command line: isolation + latency set. Decide on mitigations with security. | ✔ |
| 3 | [02](guides/02-cpu-core-isolation.md) | systemd CPUAffinity, workqueues, irqbalance off, RT throttling | ✔ (same reboot) |
| 4 | [03](guides/03-huge-pages-configuration.md) | Per-NUMA huge page reservation, sized for heap + code cache + bypass buffers | ✔ (same reboot) |
| 5 | [06](guides/06-kernel-sysctl-tuning.md) | sysctl profile | |
| 6 | [07](guides/07-os-hygiene.md) | Services, limits, noatime, tuned. Firewall section only with sign-off. | |
| 7 | [05](guides/05-cgroup-isolation.md) | housekeeping.slice for agents, pin EDR/AV | |
| 8 | [04](guides/04-network-optimization.md) | NIC roles, coalescing, IRQ affinity. Installs `lowlat-runtime.service`. | |
| 9 | [Example](examples/hugepages-java-example.md) | Launcher: options by host class, large-page flags when pinned, threads pinned by role | |
| 10 | [08](guides/08-kernel-bypass.md) | *Optional.* Kernel bypass: Onload on Solarflare/AMD NICs, or DPDK on Intel NICs (enables the IOMMU in step 2) | DPDK: ✔ (same reboot) |

```bash
scripts/apply-all --dry-run | less
sudo scripts/apply-all --apply && sudo systemctl reboot
scripts/verify-tuning
```

**Time:** half a day for the first host, including the reboot and verification. Subsequent hosts with the same hardware take minutes (same `lowlat.conf`).
**What to expect:** the biggest change is in the tail. p99.9 and max typically drop several-fold, while p50 improves modestly. The exact gain depends on how noisy the host was before, so measure against your baseline.

---

## Scenario B: Virtual machine

**For:** latency-sensitive services on KVM/VMware/Hyper-V/cloud instances. The hypervisor schedules your vCPUs, so the guest cannot truly isolate CPUs.

| Step | Guide | What applies |
|---|---|---|
| 1 | [01](guides/01-grub-bootloader-tuning.md) | **Latency subset only:** `idle=poll`, C-state caps, `transparent_hugepage=never` (agree `idle=poll` with the hypervisor owner) |
| 2 | [06](guides/06-kernel-sysctl-tuning.md) | sysctl profile (scale `vm.min_free_kbytes` down) |
| 3 | [07](guides/07-os-hygiene.md) | Services, limits, noatime, tuned profile (its PM QoS is the main C-state control in a VM) |
| 4 | [05](guides/05-cgroup-isolation.md) | Agent slice with limits |
| 5 | [04](guides/04-network-optimization.md) | Coalescing/offloads where the virtual NIC supports them; IRQ affinity for virtio/SR-IOV queues |
| 6 | App | Low-resource JVM options, **back-off** idle strategy, no large-page flags (`affinity.enable=false`) |

The scripts skip isolation, huge-page reservation, irqbalance and RT throttling automatically on `virtual_machine`.

**Biggest lever outside the guest:** ask for dedicated physical CPUs with vCPU pinning, huge-page-backed guest memory, and SR-IOV passthrough of the critical NIC. With those, the guest behaves much more like Scenario A.

---

## Scenario C: Shared bare-metal host (several applications)

**For:** a physical server running several services, where one or two need predictable latency.

| Step | Guide | What applies |
|---|---|---|
| 1 | [01](guides/01-grub-bootloader-tuning.md) | Latency subset. Isolation only for the CPUs of the one application that pins its threads (small `ISOLATED_CPUS`). |
| 2 | [05](guides/05-cgroup-isolation.md) | **One slice per tenant**: `AllowedCPUs`, `MemoryMax`, `IOWeight`. This is the main tool here. |
| 3 | [03](guides/03-huge-pages-configuration.md) | Per-node pool sized only for the latency-critical tenant |
| 4 | [04](guides/04-network-optimization.md) | Dedicated NIC (or VLAN + `tc` prioritisation, see the [segmentation example §6.3](examples/network-segmentation-example.md#63-when-traffic-classes-must-share-a-nic)) for the critical tenant |
| 5 | [06](guides/06-kernel-sysctl-tuning.md), [07](guides/07-os-hygiene.md) | As usual, without disabling services other tenants need |

---

## Pre-flight checklist

- [ ] Baseline latency and `verify-tuning --report` captured
- [ ] Out-of-band console (iLO/iDRAC/IPMI) tested
- [ ] CPU layout written down and reviewed (NUMA node of the NICs checked)
- [ ] Huge page sizing = heap + code cache + off-heap/bypass buffers + 10–20 %
- [ ] Security sign-off for mitigations and firewall changes (or leave them at `no`)
- [ ] Monitoring in place for the host (CPU per core, softirq, drops, OOM)
- [ ] Rollback steps read ([each guide](INDEX.md), final section)

## After applying

```bash
scripts/verify-tuning --report after.txt          # configuration
rtla osnoise top -c <isolated cpus> -d 60s        # noise on the isolated CPUs
# + your latency histograms vs the baseline
```

## When something goes wrong

| Problem | First action |
|---|---|
| Host does not boot | GRUB menu → `e` → remove the last added arguments → `Ctrl-x`; then `scripts/01-grub-bootloader --rollback` |
| SSH slow / host sluggish | Too few OS CPUs: check `mpstat -P ALL 1`; give CPUs back in `lowlat.conf` |
| Application cannot pin threads | cpuset trap: [Guide 05 §4.4](guides/05-cgroup-isolation.md#44-the-cpuset-trap) |
| JVM fails with large pages | Pool on the wrong node or too small: [Guide 03 §9](guides/03-huge-pages-configuration.md#9-troubleshooting) |
| Network settings gone after reboot | `systemctl status lowlat-runtime` |
| Kernel-bypass application falls back to the kernel stack | [Guide 08 §11](guides/08-kernel-bypass.md#11-troubleshooting) |
| Undo everything | Each guide's rollback section; the original files are in `/var/lib/lowlat/factory-settings/` |
