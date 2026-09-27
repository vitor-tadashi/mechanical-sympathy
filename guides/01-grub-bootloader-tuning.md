# Guide 1: GRUB Bootloader Tuning

## Overview

GRUB bootloader configuration for low-latency performance.

## Risk Level: 4/5 (System-critical - wrong config prevents boot)

## Key Kernel Parameters

- `isolcpus` — Isolate cores from scheduler
- `nohz_full` — Disable tick on isolated cores  
- `rcu_nocbs` — No-callback RCU for isolated cores
- `intel_idle.max_cstate=0` — Disable C-states
- `processor.max_cstate=0` — ACPI C-state limit
- `intel_pstate=performance` — Performance scaling
- `hugepages=N` — Pre-allocate huge pages
- `numa_balancing=0` — Disable NUMA balancing

## Bare Metal Example

```
GRUB_CMDLINE_LINUX="isolcpus=1-15 nohz_full=1-15 rcu_nocbs=1-15 intel_idle.max_cstate=0 processor.max_cstate=0 intel_pstate=performance hugepages=1024"
```

## VM Example (Conservative)

```
GRUB_CMDLINE_LINUX="hugepages=512"
```

## Apply Changes

1. Edit `/etc/default/grub`
2. Modify `GRUB_CMDLINE_LINUX`
3. Run `grub2-mkconfig -o /boot/grub2/grub.cfg`
4. Reboot: `reboot`

## Verify

```bash
cat /proc/cmdline | grep isolcpus
cat /proc/cmdline | grep hugepages
```

## Rollback

1. Edit `/etc/default/grub` - remove parameters
2. Run `grub2-mkconfig -o /boot/grub2/grub.cfg`
3. Reboot

See QUICK_START.md for deployment scenarios.
