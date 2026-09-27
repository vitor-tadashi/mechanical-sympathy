# Guide 5: Cgroup Isolation

## Overview

Isolate non-critical processes to prevent interference.

## Risk Level: 3/5 (Resource management)

## Cgroups v2 Setup

```bash
# Create cgroup for non-critical services
mkdir -p /sys/fs/cgroup/trading-critical
mkdir -p /sys/fs/cgroup/trading-non-critical

# Set resource limits
echo "+cpu +cpuset +memory" > /sys/fs/cgroup/cgroup.subtree_control
echo "1-15" > /sys/fs/cgroup/trading-critical/cpuset.cpus
echo "0" > /sys/fs/cgroup/trading-non-critical/cpuset.cpus
```

## Systemd Integration

```ini
[Service]
CPUAffinity=1-15
MemoryLimit=2G
```

## Non-Critical Processes

- SSH daemon
- System logging
- Monitoring agents
- Sidecar applications

## Verification

```bash
ps aux --forest | grep sshd
cat /proc/$(pidof sshd)/cgroup
```

## When to Apply

- Multi-application servers
- Mixed workload infrastructure
- Requirement for service isolation

See concepts/cgroups.md for v2 architecture details.
