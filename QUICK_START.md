# Quick Start: RHEL Low-Latency Tuning

Choose your scenario:

## Scenario 1: Bare Metal Dedicated Trading Server

**Best for**: Single high-performance trading application on dedicated hardware

Apply in order:
1. Guide 01: GRUB Bootloader (reboot required)
2. Guide 02: CPU Core Isolation (no reboot)
3. Guide 03: Huge Pages (reboot if GRUB method)
4. Guide 04: Network Optimization (runtime)
5. Guide 05: Cgroup Isolation (for sidecars)

**Estimated time**: 2-4 hours (+ reboots)
**Expected improvement**: 15-40% latency reduction

---

## Scenario 2: Virtual Machine

**Best for**: Trading app on hypervisor (vSphere, KVM, Xen)

Skip: Core isolation (VM can't isolate cores)

Apply:
1. Guide 01: GRUB (VM subset - mostly memory tuning)
2. Guide 03: Huge Pages (hypervisor-supported)
3. Guide 04: Network Optimization
4. Guide 05: Cgroup Isolation

**Estimated time**: 1-2 hours (+ reboot)
**Expected improvement**: 10-20% latency reduction

---

## Scenario 3: Multi-Tenant Infrastructure

**Best for**: Multiple applications on one server with isolation

Apply:
1. Guide 01: GRUB (conservative - no isolcpus)
2. Guide 03: Huge Pages
3. Guide 04: Network Optimization (per-tenant NICs)
4. Guide 05: Cgroup Isolation (resource limits per app)

**Estimated time**: 3-5 hours
**Expected improvement**: 5-15% latency reduction

---

## Pre-Flight Checklist

- [ ] Baseline metrics captured (latency P50/P99/P99.9, throughput)
- [ ] Test environment matches production hardware
- [ ] Rollback plan documented
- [ ] Team consensus on risk acceptance
- [ ] Monitoring/alerting in place

## Validation

After applying tuning:

```bash
# Check CPU isolation
cat /proc/cmdline | grep isolcpus

# Check huge pages
grep -i hugepages /proc/meminfo

# Check network coalescing
ethtool -c eth0

# Monitor latency improvement
# (Your app-specific metrics here)
```

## When Something Goes Wrong

1. Revert GRUB changes: Remove kernel parameters, rebuild, reboot
2. Restore network config: `ethtool -C eth0 rx-usecs 0`
3. Remove cgroups: systemctl stop service, rm /etc/systemd/system.conf.d/
4. Scale back: Apply changes one at a time, test each

---

See guides/ for detailed step-by-step procedures.
