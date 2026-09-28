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

## cgroups — [Guide 05](guides/05-cgroup-isolation.md#6-verification)

| Check | Command | Want |
|---|---|---|
| Agents in the slice | `systemd-cgls --no-pager /housekeeping.slice` | your agents |
| Slice fence | `cat /sys/fs/cgroup/housekeeping.slice/cpuset.cpus.effective` | the housekeeping CPUs |
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

## Time and clocks — [Guide 10](guides/10-time-sync.md#9-verification)

| Check | Command | Want |
|---|---|---|
| Clocksource | `cat /sys/devices/system/clocksource/clocksource0/current_clocksource` | `tsc` |
| chrony synced | `chronyc tracking \| grep -E 'Leap\|System time'` | `Normal`, a small offset |
| PTP locked | `journalctl -u ptp4l -n 5` | state `s2`, small `master offset` |

## Measuring — [Guide 09](guides/09-measuring-latency.md)

| Question | Command |
|---|---|
| Is this isolated CPU quiet? | `sudo rtla osnoise top -c <cpu> -d 60s` (not while the app runs on it) |
| Is my thread being preempted? | `perf stat -e context-switches,cpu-migrations -t <tid> -- sleep 10` |
| What interrupts land where? | `watch -d -n1 cat /proc/interrupts` |
| Is the VM losing time to the host? | `mpstat -P ALL 1` (`%steal`) |

Always compare against the baseline you took before tuning.
