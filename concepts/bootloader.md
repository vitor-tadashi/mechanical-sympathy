# Concept — The Boot Path and the Kernel Command Line

> Used by: [Guide 01](../guides/01-grub-bootloader-tuning.md). Related: [cpu-isolation](cpu-isolation.md), [huge-pages](huge-pages.md).

## 1. Why it matters

A handful of kernel decisions can only be made **once**, while the kernel initialises: how the scheduler groups CPUs, which CPUs run the timekeeping duty, where RCU callbacks run, which idle driver is registered, and which huge page sizes exist. The kernel command line is the only way to influence them. Getting it right is the foundation for every other latency setting. Getting it wrong can mean a host that does not boot, or one that boots and silently ignores what you asked for.

## 2. From power-on to `/proc/cmdline` (RHEL 8/9)

```
Firmware (UEFI or BIOS)
  └─► shim + GRUB2 (/boot/efi/EFI/redhat/ or MBR)
        └─► reads grub.cfg ─► "blscfg" command loads BootLoaderSpec entries
              /boot/loader/entries/<machine-id>-<kernel-version>.conf
                title   Red Hat Enterprise Linux (5.14.0-...)
                linux   /vmlinuz-5.14.0-...
                initrd  /initramfs-5.14.0-....img
                options root=/dev/mapper/rhel-root ro ... isolcpus=3,5,7 nohz_full=3,5,7 ...
        └─► loads kernel + initramfs, passes "options" as the command line
  └─► kernel: early_param() handlers run during setup_arch() (very early: memory, CPUs, IOMMU)
              __setup() handlers run later during start_kernel()
              anything unrecognised with "=" becomes an environment variable for init,
              anything unrecognised without "=" becomes an argument to init
  └─► initramfs (dracut) ─► switch_root ─► systemd (PID 1)
```

Three details matter in practice:

1. **BLS entries hold the arguments per kernel.** On RHEL 8 the `options` line often contains `$kernelopts`, a variable stored in `/boot/grub2/grubenv`. On RHEL 9 the arguments are written into each entry. `grubby` knows both layouts, which is why it is the supported tool. Editing `/etc/default/grub` alone changes neither.
2. **New kernels inherit the default entry's arguments.** `kernel-install` (run by `dnf` when a kernel is installed) copies the arguments of the current default entry, or `/etc/kernel/cmdline` if it exists. After a kernel update, verify with `grubby --info=ALL` that the new entry carries your isolation arguments.
3. **Unknown parameters fail silently.** A typo like `isolcpu=3` does not produce an error. The kernel passes it to init as an environment variable. The only reliable check is to read the kernel's own view afterwards: `/sys/devices/system/cpu/isolated`, `/sys/devices/system/cpu/nohz_full`, `/sys/kernel/mm/transparent_hugepage/enabled`.

## 3. The housekeeping model

Recent kernels organise CPU isolation around a **housekeeping mask**: the set of CPUs allowed to run kernel duties that could otherwise land anywhere. `isolcpus` and `nohz_full` remove CPUs from this mask for different *types* of work:

| Housekeeping type | Removed by | Work that moves to housekeeping CPUs |
|---|---|---|
| `domain` | `isolcpus=` (default flag) | Scheduler load balancing, so tasks are never migrated onto the CPU |
| `managed_irq` | `isolcpus=managed_irq,...` | Kernel-managed device IRQ vectors (best effort) |
| `timer` | `nohz_full=` | Unbound timers, and the global timekeeping duty (`do_timer`) |
| `rcu` | `nohz_full=` / `rcu_nocbs=` | RCU callback processing (`rcuo*` kthreads) and grace-period kthreads |
| `misc`, `kthread` | `nohz_full=` | Unbound kernel threads created at runtime (`kthreadd` children) |
| `wq` | `nohz_full=` (default unbound workqueue mask) | Unbound workqueue items. Refine with `/sys/devices/virtual/workqueue/cpumask`. |

This is why the parameters are used **together** and with the **same CPU list**. Each one removes a different class of work, and none of them alone produces a quiet CPU.

## 4. How the main parameters work

### `isolcpus=<list>`

At boot, the scheduler builds *scheduling domains*, a hierarchy (SMT siblings → cores sharing L2 → socket/LLC → NUMA) over which it balances load. CPUs in `isolcpus` are placed in no domain (each is effectively its own). Consequences:

- no task is ever *pulled* or *pushed* onto them by load balancing;
- a task lands there only if its affinity mask lets it and it is *placed* there (fork/exec/wakeup on that CPU, or an explicit `sched_setaffinity`);
- a task whose mask spans several isolated CPUs **stays on the first one**, because nothing balances them.

It does not move per-CPU kernel threads, and it does not change interrupt routing.

### `nohz_full=<list>` (adaptive ticks)

Normally every CPU takes a periodic timer interrupt (`CONFIG_HZ`, 1000 on RHEL) that accounts CPU time, runs the scheduler tick, expires timers, and advances RCU. With `nohz_full`, when a CPU has **exactly one runnable task**, the tick is stopped:

- time accounting switches to context-tracking at kernel entry/exit instead of sampling at every tick;
- RCU treats the CPU as being in an extended quiescent state while it runs user code;
- a **residual 1 Hz tick** remains for scheduler statistics. On recent kernels it is offloaded to a housekeeping CPU through a workqueue, and on older ones it still hits the CPU once per second.

The cost: every user↔kernel transition on a `nohz_full` CPU is slightly more expensive (context tracking). A thread that makes many syscalls gets *slower*. The design assumes the isolated thread stays in user space: spinning on memory, a ring buffer, or a kernel-bypass NIC queue.

### `rcu_nocbs=<list>` and `rcu_nocb_poll`

RCU (Read-Copy-Update) lets readers run without locks; writers defer freeing old data until every CPU has passed a quiescent state, then run **callbacks**. By default those callbacks run in softirq context on the CPU that queued them, in batches that can take hundreds of µs. `rcu_nocbs` offloads callback execution for the listed CPUs to `rcuo<type>/<cpu>` kthreads, which the scheduler keeps on housekeeping CPUs. `rcu_nocb_poll` makes those kthreads poll periodically instead of being woken by the isolated CPU, which removes a wake-up IPI. It is a boolean flag and takes no value.

### `idle=poll`, `processor.max_cstate`, `intel_idle.max_cstate`

When a CPU has nothing to run, the idle loop picks a C-state through the cpuidle governor. Deeper states save more power, but on wake-up the core has to restore voltage, clocks and possibly flushed caches. Exit latencies range from ~1 µs (C1) to ~100+ µs (C6 package states), and the wake-up is on the critical path of the next interrupt. `idle=poll` replaces the idle loop with a spin, so the CPU never enters any C-state. The two `max_cstate` parameters cap the idle drivers in case polling is ever turned off.

### `transparent_hugepage=never`, `default_hugepagesz`, `hugepagesz`

These configure the memory subsystem before any allocation happens. THP is disabled, the size of explicit huge pages is registered, and the default size is set for `MAP_HUGETLB` without a size flag and for hugetlbfs mounts without `pagesize=`. See [huge-pages.md](huge-pages.md).

### Mitigation switches (`pti=off`, `nospectre_v2`, `mds=off`, ...)

They are read in `setup_arch()`, and the kernel **patches its own code** at boot (alternatives) to include or exclude barriers, retpolines, `VERW` buffer clears, and page-table switches on every kernel entry/exit. Once patched, they cannot be changed at runtime. This is why the choice belongs on the command line, and why it affects every syscall and interrupt.

## 5. How this relates to latency

| Parameter group | Removes | Order of magnitude |
|---|---|---|
| `nohz_full` | 250–1000 tick interrupts/s | 1–5 µs each |
| `rcu_nocbs` | RCU callback batches in softirq | 10–500 µs, occasionally |
| `isolcpus` + systemd affinity | other tasks' time slices | ms |
| `idle=poll` / C-state caps | wake-up latency after idle | 1–100 µs per wake-up |
| `nosoftlockup`, `nmi_watchdog=0` | watchdog hrtimer + NMI | µs, periodic |
| `pti=off` etc. | per-syscall/per-IRQ mitigation overhead | 0.1–several µs per transition |
| `transparent_hugepage=never` | compaction stalls, `khugepaged` | up to ms |

## 6. Common real-world situations

- **"We set isolcpus but the latency did not change."** Usually the application threads were never pinned (so they run on OS CPUs), or were pinned to a range and all stacked on the first CPU. Check with `ps -eLo psr,comm`.
- **"After the kernel update the isolation disappeared."** The new BLS entry did not inherit the arguments (a custom `/etc/kernel/cmdline`, or the default entry changed). Check `grubby --info=ALL` after every kernel update. `verify-tuning` flags it on the first boot.
- **"The interfaces were renamed after tuning."** `biosdevname` changed on the command line. The naming scheme is decided in early userspace (udev), based on this argument.
- **"A security scan flags the host."** Expected when mitigations are off. The exception must be documented and scoped to that host class.

## 7. References

- <https://docs.kernel.org/admin-guide/kernel-parameters.html>
- <https://docs.kernel.org/timers/no_hz.html>
- <https://docs.kernel.org/RCU/whatisRCU.html>
- BootLoaderSpec: <https://uapi-group.org/specifications/specs/boot_loader_specification/>
- `man 8 grubby`, `man 8 kernel-install`
- Frederic Weisbecker, "NO_HZ: Reducing Scheduling-Clock Ticks" (kernel docs) and the LWN series on housekeeping and CPU isolation
