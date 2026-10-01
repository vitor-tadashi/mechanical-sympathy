# Index

## Reading paths

Pick the lane that matches your role. Each box is one page, read left to right, and the links for every step are listed under the diagram.

```mermaid
flowchart TD
  subgraph op["Operator: apply the tuning (about half a day for the first host)"]
    direction LR
    o0["Quick start"] --> o00["00<br/>BIOS"] --> o1["01<br/>GRUB"] --> o2["02<br/>CPUs"] --> o3["03<br/>Huge pages"] --> o4["04<br/>Network"] --> o5["05<br/>cgroups"] --> o6["06<br/>sysctl"] --> o7["07<br/>Hygiene"] --> o10["10 Time<br/>11 Day-2"] --> ov[["verify-tuning"]]
    o7 -.-> o8["08 Bypass<br/>(only with a<br/>bypass stack)"] -.-> o10
  end
  subgraph story["Learner: from stories"]
    direction LR
    s1["Use case 1<br/>The quiet core"] --> s2["Use case 2<br/>Critical and<br/>non-critical"] --> s3["Use case 8<br/>Capstone"] --> s4["Layout<br/>explorer"]
  end
  subgraph dev["Application developer: how my code should behave"]
    direction LR
    d1["02 §6<br/>Pinning"] --> d2["03 §5<br/>Java flags"] --> d3["Java example"] --> d4["Concept:<br/>caches and coherence"]
  end
  subgraph mgr["Manager or reviewer: what, why, what can go wrong"]
    direction LR
    m1["README<br/>Read this first"] --> m2["Risk tables<br/>atop each guide"] --> m3["01 §5.6<br/>Mitigations"] --> m4["07 §6<br/>Firewall"]
  end
  subgraph net["Network engineer"]
    direction LR
    n1["04<br/>Network"] --> n2["Concept:<br/>network path"] --> n3["Concept:<br/>ethtool"] --> n4["08<br/>Bypass"] --> n5["Segmentation<br/>example"] --> n6["06 §3-6<br/>TCP, buffers"]
  end
  op ~~~ story ~~~ dev ~~~ mgr ~~~ net
  classDef risk fill:#ffc9c9,stroke:#9b1c1c,color:#2b0a0a
  class m3,m4 risk
```

*Five lanes: the operator walks guides 00 to 07, then 10 and 11 (08 only with kernel bypass), and ends at verify-tuning; the learner follows three use cases and the layout explorer; the developer reads the pinning and Java sections and the Java example; the reviewer reads the risks, with mitigations and firewall highlighted; the network engineer goes from Guide 04 through the network concepts to bypass and segmentation.*

**Operator applying the tuning (about half a day for the first host, minutes for the next)**
[QUICK_START](QUICK_START.md) → [00](guides/00-bios-firmware.md) → [01](guides/01-grub-bootloader-tuning.md) → [02](guides/02-cpu-core-isolation.md) → [03](guides/03-huge-pages-configuration.md) → [04](guides/04-network-optimization.md) → [05](guides/05-cgroup-isolation.md) → [06](guides/06-kernel-sysctl-tuning.md) → [07](guides/07-os-hygiene.md) → ([08](guides/08-kernel-bypass.md), only with a bypass stack) → [10](guides/10-time-sync.md) → [11](guides/11-day2-operations.md) → `scripts/verify-tuning`

**Learner (from stories)**
[Use case 1 — the quiet core](examples/use-cases/01-the-quiet-core.md) → [Use case 2 — critical and non-critical threads](examples/use-cases/02-critical-and-non-critical.md) → [Use case 8 — the capstone](examples/use-cases/08-stock-to-tuned-in-one-afternoon.md) → the [layout explorer](https://vitor-tadashi.github.io/mechanical-sympathy/explorer.html)

**Application developer (how my code should behave on a tuned host)**
[Guide 02 §6 — pinning the application](guides/02-cpu-core-isolation.md#6-pinning-the-application) → [Guide 03 §5 — Java flags](guides/03-huge-pages-configuration.md#5-java-applications) → [Java example](examples/hugepages-java-example.md) → [concepts/cpu-isolation §5 — caches and coherence](concepts/cpu-isolation.md#5-caches-and-coherence-the-mechanical-sympathy-part)

**Engineering manager / reviewer (what, why, and what can go wrong)**
[README — Read this first](README.md#read-this-first) → [Safety](SAFETY.md) → risk and applicability tables at the top of each guide → [Guide 01 §5.6 — mitigations](guides/01-grub-bootloader-tuning.md#56-iommu-and-cpu-vulnerability-mitigations-security-sensitive) → [Guide 07 §6 — firewall](guides/07-os-hygiene.md#6-opt-in-removing-host-packet-filtering)

**Network engineer**
[Guide 04](guides/04-network-optimization.md) → [concepts/network-tuning](concepts/network-tuning.md) → [concepts/ethtool](concepts/ethtool.md) → [Guide 08 — kernel bypass](guides/08-kernel-bypass.md) → [segmentation example](examples/network-segmentation-example.md) → [Guide 06 §3–6](guides/06-kernel-sysctl-tuning.md#3-tcp-behavior) → [Guide 10 — time sync](guides/10-time-sync.md)

## Guides

| Guide | Read | Covers | Key functions |
|---|---|---|---|
| [00 BIOS and firmware](guides/00-bios-firmware.md) | ~14 min | power profile, C-states, P-states and turbo, EPB, uncore, Hyper-Threading, NUMA/SNC, SMI sources, PCIe ASPM, cooling | `set_pcie_aspm_policy`, `verify_bios_firmware`, `show_firmware_facts` |
| [01 Kernel command line](guides/01-grub-bootloader-tuning.md) | ~17 min | isolcpus, nohz_full, rcu_nocbs, idle/C-states, THP, huge page size, watchdogs, IOMMU, mitigations | `apply_grub_kernel_parameters`, `rollback_grub_kernel_parameters` |
| [02 CPU isolation](guides/02-cpu-core-isolation.md) | ~15 min | CPU layout, systemd CPUAffinity, workqueues, irqbalance, RT throttling, thread pinning, idle strategies | `configure_systemd_cpu_affinity`, `set_workqueue_affinity`, `pin_process`, `show_affinity` |
| [03 Huge pages](guides/03-huge-pages-configuration.md) | ~15 min | THP vs explicit, sizing, per-NUMA early-boot reservation, Java flags, C/C++ mmap, 1 GiB pages | `install_hugepage_reservation`, `set_hugepage_sysctls`, `show_hugepages` |
| [04 Network](guides/04-network-optimization.md) | ~22 min | NIC roles, channels (one queue per IRQ CPU), ntuple steering, coalescing, pause, offloads, rings, txqueuelen, IRQ affinity, RPS/XPS, persistence | `tune_nic_low_latency`, `set_nic_irq_affinity`, `show_nic_state` |
| [05 cgroups](guides/05-cgroup-isolation.md) | ~10 min | v1/v2, housekeeping slice, agent pinning, cpuset trap, app unit template, cpuset partitions | `create_housekeeping_slice`, `move_service_to_slice`, `pin_housekeeping_processes` |
| [06 sysctl](guides/06-kernel-sysctl-tuning.md) | ~11 min | logging, TCP, buffers, queues, IPv6/ARP, BPF, VM | `write_sysctl_profile`, `apply_sysctl_profile` |
| [07 OS hygiene](guides/07-os-hygiene.md) | ~9 min | services, limits, noatime, tuned, opt-in firewall/netfilter | `disable_unnecessary_services`, `set_security_limits`, `install_tuned_profile` |
| [08 Kernel bypass](guides/08-kernel-bypass.md) | ~18 min | choosing a stack per card and application, what happens to the kernel queues, Onload on Solarflare/AMD, DPDK on Intel (VFIO, IOMMU), XLIO, AF_XDP, busy polling | `apply_onload`, `bind_dpdk_ports`, `unbind_dpdk_ports`, `show_bypass_state` |
| [09 Measuring latency](guides/09-measuring-latency.md) | ~14 min | baselines, percentiles, coordinated omission, rtla osnoise/timerlat/hwnoise, turbostat SMIs, a measurement protocol, reading histogram shapes | `install_measurement_tools`, `capture_bundle`, `verify_measurement` |
| [10 Time synchronization](guides/10-time-sync.md) | ~11 min | chrony vs PTP, hardware timestamping, the timing NIC, pinning the time daemons, ptp4l + phc2sys, VMs (`ptp_kvm`) | `pin_time_daemons`, `configure_chrony`, `configure_ptp`, `verify_time_sync` |
| [11 Day-2 operations](guides/11-day2-operations.md) | ~10 min | the verification timer, kernel updates and the boot loader entries, what to alert on, adding a thread, an update routine | `install_verify_timer`, `all_kernel_entries_isolated`, `verify_day2_operations` |

## Concepts

| Concept | Read | Questions it answers |
|---|---|---|
| [Hardware topology](concepts/hardware-topology.md) | ~9 min | Which CPUs share a core, an L3, a node? How far is the NIC from my thread? How do I read the topology before writing a layout? |
| [Power, frequency & firmware](concepts/power-and-frequency.md) | ~10 min | Why is the first message after a pause slow? Who chooses the clock? Is turbo worth it? Why does an SMI leave no trace? |
| [Clocks and time](concepts/clocks-and-time.md) | ~9 min | Which clock do I read for a duration? Why can a latency be negative? What does the clocksource cost? How good is a one-way latency across hosts? |
| [Security mitigations](concepts/security-mitigations.md) | ~8 min | What do Spectre and Meltdown fixes cost, and where? Who pays: a spinning thread or a blocking one? How do I measure it before opting out? |
| [Interrupts & deferred work](concepts/interrupts-and-deferred-work.md) | ~10 min | What runs after an interrupt, and where? When does ksoftirqd take over? Which IPIs reach an isolated CPU, and why? Where do RCU callbacks and kworkers run? |
| [Tail latency](concepts/tail-latency.md) | ~9 min | Why does p99 matter to every user? How many samples does a percentile need? Why can percentiles not be averaged? What does the histogram shape say? |
| [Queueing](concepts/queueing.md) | ~9 min | Why does p99 explode as load rises? What does Little's law tell me? Why does jitter cost as much as capacity? How long does one stall echo? |
| [Thread handoff](concepts/thread-handoff.md) | ~10 min | What does passing a message between two cores cost? What is false sharing, and how do I pad? Acquire, release or volatile? Spin, back off or block? |
| [Boot path](concepts/bootloader.md) | ~7 min | How do arguments reach the kernel? What is the housekeeping mask? Why can't these be changed at runtime? |
| [CPU isolation](concepts/cpu-isolation.md) | ~7 min | What interrupts a CPU? What does a context switch really cost? Spin or block? |
| [Network path](concepts/network-tuning.md) | ~8 min | Where does a packet wait between the wire and `recv()`? What do coalescing, NAPI, RSS, and bypass change? |
| [Network buffers](concepts/network-buffers.md) | ~10 min | How big is each queue on the way to `recv()`? How long does a ring hold a burst? Where did the packet die, and which counter shows it? What do DPDK and Onload change? |
| [`ethtool` reference](concepts/ethtool.md) | ~16 min | What is a channel, and what does `combined` mean? Which options reset the link? How do I steer one flow to one queue? How do I persist each setting? |
| [Memory reclaim & faults](concepts/memory-reclaim.md) | ~10 min | Where does the memory go? Who reclaims it, kswapd or my thread? What does a minor or major fault cost? Why do stalls appear only after days of uptime? |
| [Swap & the OOM killer](concepts/swap-and-oom.md) | ~9 min | What can be swapped, and what does a swap-in cost? What does swappiness really do? How does the OOM killer choose? Why prefer a loud failure? |
| [Logging & I/O](concepts/logging-and-io.md) | ~9 min | Where can a log line block? What do dirty throttling, fsync and the kernel console cost? How do I log without doing I/O on the hot path? |
| [Huge pages & NUMA](concepts/huge-pages.md) | ~7 min | What is TLB reach? Why pre-touch? Why is THP unpredictable? Why reserve per node? |
| [JVM pauses](concepts/jvm-pauses.md) | ~10 min | Why does a pinned Java thread still stop? What is time to safepoint? What does ZGC still pause for? Which JVM stalls are not pauses, and how do I log them? |
| [cgroups](concepts/cgroups.md) | ~5 min | Affinity vs cpuset? What do quota, memory.max, io.weight do? How does systemd map onto cgroups? |

## Examples

| Example | Read | Shows |
|---|---|---|
| [Use cases](examples/use-cases/README.md) | ~6 min each | Stories from symptom to result: [the quiet core](examples/use-cases/01-the-quiet-core.md), [critical and non-critical threads](examples/use-cases/02-critical-and-non-critical.md), [the noisy neighbor](examples/use-cases/03-the-noisy-neighbor.md), [one NIC, one queue, one CPU](examples/use-cases/04-one-nic-one-queue-one-cpu.md), [page faults](examples/use-cases/05-page-faults-on-the-hot-path.md), [two sockets, one mistake](examples/use-cases/06-two-sockets-one-mistake.md), [the freeze nobody logs](examples/use-cases/07-the-freeze-nobody-logs.md), a [capstone](examples/use-cases/08-stock-to-tuned-in-one-afternoon.md), [the two-millisecond burst](examples/use-cases/09-the-two-millisecond-burst.md), [line rate without the kernel](examples/use-cases/10-line-rate-without-the-kernel.md), [the first message after a quiet spell](examples/use-cases/11-the-first-message-after-a-quiet-spell.md), [the sibling that shares your core](examples/use-cases/12-the-sibling-that-shares-your-core.md), [turbo, the lottery](examples/use-cases/13-turbo-the-lottery.md), [the spinner that stalled the kernel](examples/use-cases/14-the-spinner-that-stalled-the-kernel.md), [the coalescing timer](examples/use-cases/15-the-coalescing-timer.md), [the log line that cost five milliseconds](examples/use-cases/16-the-log-line-that-cost-five-milliseconds.md), [memory pressure on a latency host](examples/use-cases/17-memory-pressure-on-a-latency-host.md), [adding a worker without re-planning](examples/use-cases/18-adding-a-worker-without-re-planning.md) and [the benchmark that lied](examples/use-cases/19-the-benchmark-that-lied.md). Each has the diagnosis commands, the exact config lines, and the rollback |
| [Java on a tuned host](examples/hugepages-java-example.md) + [code](examples/java-latency-probe/) | ~9 min | Launcher by host class, large pages + NUMA + pre-touch when pinned, thread roles → CPUs, padded single-writer sequences, RTT and TLB-walk histograms |
| [Multi-NIC segmentation](examples/network-segmentation-example.md) | ~9 min | Six NICs in four roles, routing with one default route, IRQ/CPU map, qdisc per role, `tc` prioritization on a shared NIC, PTP, persistence matrix |

## Scripts

| Script | Use |
|---|---|
| [`lowlat.conf.example`](scripts/lowlat.conf.example) | Describe the host. Copy to `/etc/lowlat/lowlat.conf`. |
| [`plan-layout`](scripts/plan-layout) `--threads N --nic-node N` | Propose the CPU layout of `lowlat.conf` from `lscpu`, or `--check` one you wrote by hand. The [explorer](https://vitor-tadashi.github.io/mechanical-sympathy/explorer.html) does the same in a browser |
| `NN-* --dry-run / --apply / --verify / --rollback` | One guide at a time (00–11). `09-measure-latency --run` captures a measurement bundle. |
| [`apply-all`](scripts/apply-all) `--plan / --dry-run / --apply / --runtime / --rollback` | All guides in order, with step timing, and the whole-host rollback |
| [`size-buffers`](scripts/size-buffers) `--burst-mpps R --ring N` | How long a burst lasts and how big the ring and the socket buffer must be to lose nothing. The [simulator](https://vitor-tadashi.github.io/mechanical-sympathy/buffers.html) does the same in a browser |
| [`verify-tuning`](scripts/verify-tuning) `[--report FILE]` | Read-only PASS/WARN/FAIL for everything |
| [`systemd/lowlat-runtime.service`](scripts/systemd/lowlat-runtime.service) | Re-applies runtime state at boot |

## Glossary

Every abbreviation, product and unusual word has an entry in the [Glossary](GLOSSARY.md), written in plain English for readers whose first language is not English. Start there when a term such as [SMI](GLOSSARY.md#smi), [NAPI](GLOSSARY.md#napi) or [housekeeping CPU](GLOSSARY.md#housekeeping-cpu) is new.
