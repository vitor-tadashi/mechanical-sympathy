# Guide 4: Network Optimization

## Overview

Optimize network I/O for low-latency trading.

## Risk Level: 3/5 (Mostly runtime configuration)

## Key Configurations

### IRQ Affinity
```bash
# Pin NIC interrupts to specific cores
echo "2" > /proc/irq/24/smp_affinity  # Hex: core 1
echo "4" > /proc/irq/25/smp_affinity  # Hex: core 2
```

### Interrupt Coalescing
```bash
# Disable coalescing on critical NICs
ethtool -C eth0 rx-usecs 0 tx-usecs 0 rx-frames 1 tx-frames 1

# Enable on non-critical NICs
ethtool -C eth1 rx-usecs 100 rx-frames 32
```

### Network Stack Tuning
```bash
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728
sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
```

## 3-Network Segmentation

1. **Client Access** (10GB+) — Market data, order input
2. **Internal Critical** (10GB+) — Gateway-to-Gateway
3. **Internal Non-Critical** (1GB+) — SSH, monitoring

## Network Interface Reference

- em1 — PTP/Critical (coalescing=0)
- em2 — Backend/Critical (coalescing=0)
- p1p1 — Frontend/Critical (coalescing=0)
- p2p1 — Non-Critical (coalescing=300000)
- p2p2 — Non-Critical (coalescing=300000)

## Verification

```bash
ethtool -c eth0
cat /proc/irq/24/smp_affinity
sysctl net.core.rmem_max
```

## Persistent Configuration

Add to `/etc/sysctl.d/99-trading.conf` and run `sysctl -p`

See concepts/network-tuning.md for protocol impact analysis.
