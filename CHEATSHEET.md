# Cheat Sheet — Is This Host Tuned?

The "I have two minutes" page. One command per check, with the answer you want to see. Every check links to the guide section that explains it and fixes it.

> [!TIP]
> `scripts/verify-tuning` runs most of these for you and prints PASS/WARN/FAIL. Use this page when you want to look at one thing by hand, or on a host without the scripts.

## Firmware — [Guide 00](guides/00-bios-firmware.md#7-verification)

| Check | Command | Want |
|---|---|---|
| Hyper-Threading off | `cat /sys/devices/system/cpu/smt/active` | `0` |
| One NUMA node per socket | `numactl --hardware \| head -1` | `available: 2 nodes` on two sockets |
| No SMIs | `sudo turbostat --quiet --interval 10 --num_iterations 1 --show SMI` | `0`, or a small constant count |
| Energy bias | `cat /sys/devices/system/cpu/cpu0/power/energy_perf_bias` | `0` |

## Kernel command line — [Guide 01](guides/01-grub-bootloader-tuning.md#7-verification)

| Check | Command | Want |
|---|---|---|
| Arguments present | `tr ' ' '\n' </proc/cmdline \| grep -E 'isolcpus\|nohz_full\|rcu_nocbs\|idle=poll'` | all four |
| Kernel accepted the lists | `cat /sys/devices/system/cpu/isolated /sys/devices/system/cpu/nohz_full` | your isolated CPUs, twice |
| THP off | `cat /sys/kernel/mm/transparent_hugepage/enabled` | `always madvise [never]` |
| No idle driver | `cat /sys/devices/system/cpu/cpuidle/current_driver` | `none` |
| Frequency driver | `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver` | `acpi-cpufreq` |

## CPU isolation — [Guide 02](guides/02-cpu-core-isolation.md#8-verification)

| Check | Command | Want |
|---|---|---|
| OS mask on PID 1 | `grep Cpus_allowed_list /proc/1/status` | the OS CPUs only |
| Nothing else on isolated CPUs | `ps -eLo psr,comm \| awk '$1==5'` (per isolated CPU) | your pinned thread, plus sleeping per-CPU kthreads |
| Workqueue mask | `cat /sys/devices/virtual/workqueue/cpumask` | the workqueue CPUs only |
| irqbalance off | `systemctl is-active irqbalance` | `inactive` |
| RT throttling off | `sysctl -n kernel.sched_rt_runtime_us` | `-1` |
| Tick stopped | `rtla osnoise top -c 5 -d 30s` | single-digit µs max noise |

## Huge pages — [Guide 03](guides/03-huge-pages-configuration.md#8-verification)

| Check | Command | Want |
|---|---|---|
| Pool per node | `cat /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages` | your `HUGEPAGES_PER_NODE` |
| Reservation ran | `journalctl -b -u hugetlb-reserve-pages` | requested = reserved |
| JVM on huge pages | `grep HugePages_Free /proc/meminfo` before and after start | dropped by heap + code cache |

## Network — [Guide 04](guides/04-network-optimization.md#9-verification)

| Check | Command | Want |
|---|---|---|
| Coalescing | `ethtool -c ens1f0 \| grep -E 'Adaptive\|rx-usecs'` | `Adaptive RX: off`, `rx-usecs: 0` |
| PAUSE off | `ethtool -a ens1f0` | `RX: off`, `TX: off` |
| One queue per IRQ CPU | `ethtool -l ens1f0` | `Combined` = number of IRQ CPUs |
| IRQs on the housekeeping CPU | `watch -d -n1 "grep -E 'CPU\|ens1f0' /proc/interrupts"` | only the IRQ CPU's column moves |
| No drops | `ethtool -S ens1f0 \| grep -iE 'drop\|miss' \| grep -v ': 0$'` | nothing |
| Runtime unit ran | `systemctl status lowlat-runtime` | `active (exited)` |
| Socket buffer drops | `nstat -az \| grep -E 'UdpRcvbufErrors\|TCPRcvQDrop'` | 0, and no growth |
| Softirq budget | `awk '{print NR-1, $3}' /proc/net/softnet_stat` | column 3 (`time_squeeze`) not growing |
| Which stage drops | [Concept: network buffers §6](concepts/network-buffers.md#6-where-did-the-packet-die) | one counter per stage |

## cgroups — [Guide 05](guides/05-cgroup-isolation.md#6-verification)

| Check | Command | Want |
|---|---|---|
| Agents in the slice | `systemd-cgls --no-pager /housekeeping.slice` | your agents |
| Slice fence | `cat /sys/fs/cgroup/housekeeping.slice/cpuset.cpus.effective` | your `HOUSEKEEPING_SLICE_CPUS` |
| Quota not starving agents | `grep nr_throttled /sys/fs/cgroup/housekeeping.slice/cpu.stat` | not climbing fast |

## sysctl — [Guide 06](guides/06-kernel-sysctl-tuning.md#10-verification)

| Check | Command | Want |
|---|---|---|
| Profile loaded | `sysctl net.core.rmem_max vm.stat_interval kernel.numa_balancing` | `134217728`, `60`, `0` |
| Nobody overrides it | `systemd-analyze cat-config sysctl.d \| grep -n rmem_max` | the last one is `90-lowlat.conf` |

## OS hygiene — [Guide 07](guides/07-os-hygiene.md#9-verification)

| Check | Command | Want |
|---|---|---|
| tuned profile | `tuned-adm active` | `low-latency` |
| Governor | `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` | `performance` |
| Limits for the app user | `ulimit -n -l -r` (as `app-user`, new session) | `65535`, `unlimited`, `99` |

## Kernel bypass — [Guide 08](guides/08-kernel-bypass.md#9-verification)

| Check | Command | Want |
|---|---|---|
| Onload accelerating | `onload_stackdump` | one stack per accelerated process |
| DPDK ports bound | `dpdk-devbind.py --status-dev net` | your ports under `drv=vfio-pci` |

## Measuring — [Guide 09](guides/09-measuring-latency.md)

| Question | Command |
|---|---|
| Is this isolated CPU quiet? | `sudo rtla osnoise top -c <cpu> -d 60s` (not while the app runs on it) |
| Is my thread being preempted? | `perf stat -e context-switches,cpu-migrations -t <tid> -- sleep 10` |
| What interrupts land where? | `watch -d -n1 cat /proc/interrupts` |
| Is the VM losing time to the host? | `mpstat -P ALL 1` (`%steal`) |

Always compare against the baseline you took before tuning.

## Time and clocks — [Guide 10](guides/10-time-sync.md#9-verification)

| Check | Command | Want |
|---|---|---|
| Clocksource | `cat /sys/devices/system/clocksource/clocksource0/current_clocksource` | `tsc` |
| chrony synced | `chronyc tracking \| grep -E 'Leap\|System time'` | `Normal`, a small offset |
| PTP locked | `journalctl -u ptp4l -n 5` | state `s2`, small `master offset` |

## Staying tuned — [Guide 11](guides/11-day2-operations.md#8-verification)

| Check | Command | Want |
|---|---|---|
| Timer installed | `systemctl list-timers lowlat-verify.timer` | a NEXT time |
| Last report | `systemctl show -p Result --value lowlat-verify.service` | `success` |
| Layout follows the rules of Guide 02 §3 | `scripts/plan-layout --nic-node N --check /etc/lowlat/lowlat.conf` | every line `PASS` |
| Kernel entries keep the arguments | `grubby --info=ALL \| grep -E '^(kernel\|args)='` | `isolcpus=`, `nohz_full=` and `rcu_nocbs=` on every entry but rescue |

## Memory pressure — [Guide 12](guides/12-memory-pressure.md#6-verification)

| Check | Command | Want |
|---|---|---|
| No swap (`SWAP_POLICY=off`) | `swapon --show` | nothing |
| Nothing swapped in since boot | `grep pswpin /proc/vmstat` | `pswpin 0` |
| OOM order of the latency service | `systemctl show -p OOMScoreAdjust lowlat-app.service` | `OOMScoreAdjust=-900` |
| `mlockall` can work | `systemctl show -p LimitMEMLOCK lowlat-app.service` | `LimitMEMLOCK=infinity` |
| No memory stalls | `cat /proc/pressure/memory` | `full avg300=0.00` or close |

## Orders of magnitude

The numbers every page in this repository uses. They are typical values from the concept pages, not measurements: measure your own host before you rely on one.

| Event | Typical cost | Explained in |
|---|---|---|
| L1 / L2 / L3 hit | ~1 ns / ~5 ns / ~15–20 ns | [Hardware topology §3](concepts/hardware-topology.md#3-numbers-to-remember) |
| Cache line handoff: same L3 domain / other L3, same socket / other socket | ~20–40 ns / ~60–120 ns / ~130–200 ns | [Hardware topology §3](concepts/hardware-topology.md#3-numbers-to-remember) |
| DRAM: local / remote | ~80–120 ns / local + ~60–100 ns | [Hardware topology §3](concepts/hardware-topology.md#3-numbers-to-remember) |
| Spinning consumer sees a new message (same L3) | ~50–100 ns | [Thread handoff §5](concepts/thread-handoff.md#5-waiting-for-the-next-message) |
| Blocked thread woken up | 2–50 µs | [Thread handoff §5](concepts/thread-handoff.md#5-waiting-for-the-next-message) |
| Scheduler tick | 1–5 µs each, 1000 per second (RHEL x86_64) | [Interrupts §2](concepts/interrupts-and-deferred-work.md#2-execution-contexts-from-most-urgent-to-least) |
| Hard interrupt alone / with its softirq work | 1–5 µs / up to ~50 µs | [Interrupts §8](concepts/interrupts-and-deferred-work.md#8-numbers-to-remember) |
| Packet from the NIC to `recv()`: kernel stack / kernel bypass | ~5–10 µs / ~1–2 µs | [Network path](concepts/network-tuning.md) |
| Adaptive interrupt coalescing, first packet of a burst | +30–50 µs | [Guide 04 §5.2](guides/04-network-optimization.md#52-adaptive-coalescing-off-ethtool--c-adaptive-rx-off-adaptive-tx-off) |
| Deep C-state exit / SMI | tens to hundreds of µs, rarely ms | [Power and frequency](concepts/power-and-frequency.md) |
| RT throttling of a `SCHED_FIFO` spinner | 50 ms every second | [Guide 02](guides/02-cpu-core-isolation.md) |
| TCP retransmit after a drop | ≥ 200 ms | [Network path](concepts/network-tuning.md) |
| NTP on a quiet LAN / PTP with hardware timestamps | 10–100 µs / below 1 µs | [Clocks and time](concepts/clocks-and-time.md) |
| Samples to trust p99.99 | ~1,000,000 (10,000,000 is comfortable) | [Guide 09 §3.2](guides/09-measuring-latency.md#32-enough-samples) |
