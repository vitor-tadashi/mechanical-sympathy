# Mechanical Sympathy: Low-Latency RHEL Tuning Guide

> **"Write code that works with the machine, not against it."** — Mechanical Sympathy is about understanding how software interacts with hardware.

## 📋 Quick Navigation

- **QUICK_START.md** — 3 deployment scenarios (Bare Metal, VM, Multi-tenant)
- **guides/** — Detailed configuration guides
- **concepts/** — Deep-dive technical concepts
- **examples/** — Real-world implementation examples

## ⚠️ Critical Disclaimer

This documentation is specifically designed for **bare metal servers running well-designed, well-implemented trading infrastructure applications** that prioritize low-latency performance.

**This is NOT a one-size-fits-all solution.**

- Some optimizations improve **latency but may reduce throughput**
- Configurations for single-purpose latency-critical apps may **hurt performance** for applications with hundreds of threads
- **Incorrect application can degrade performance** and create operational complexity
- Changes persist across reboots; rollback requires explicit action

### When NOT to Apply These

- Application hasn't been profiled for latency requirements
- Running multiple unrelated applications on same server
- Application doesn't properly manage CPU affinity
- Running on VMs without hardware-level core isolation
- Infrastructure team lacks kernel tuning expertise

## 🎯 Tuning Domains

1. **GRUB Bootloader Tuning** (Risk: 4/5) — Kernel parameters, CPU isolation
2. **CPU Core Isolation** (Risk: 4/5) — Core pinning, context switch prevention
3. **Huge Pages Configuration** (Risk: 3/5) — TLB miss reduction
4. **Network Optimization** (Risk: 3/5) — IRQ affinity, coalescing
5. **Cgroup Isolation** (Risk: 3/5) — Non-critical process isolation

## 📁 Structure

```
mechanical-sympathy/
├── README.md (this file)
├── QUICK_START.md
├── INDEX.md
├── guides/
│   ├── 01-grub-bootloader-tuning.md
│   ├── 02-cpu-core-isolation.md
│   ├── 03-huge-pages-configuration.md
│   ├── 04-network-optimization.md
│   └── 05-cgroup-isolation.md
├── concepts/
├── examples/
└── scripts/
```

## 🚀 Next Steps

1. Read QUICK_START.md for your scenario
2. Jump to relevant guide in guides/
3. Reference concept docs for deeper understanding
4. Use examples/ for integration patterns

---

**For ByBit**: Foundation-ready documentation demonstrating deep expertise in low-latency infrastructure tuning.
