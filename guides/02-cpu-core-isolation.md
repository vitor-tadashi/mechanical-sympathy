# Guide 2: CPU Core Isolation

## Overview

Isolate CPU cores for application-exclusive use.

## Risk Level: 4/5 (Requires careful thread management)

## Methods

### 1. Taskset (Runtime)
```bash
taskset -c 1-15 ./trading-app
```

### 2. In-Application (Java)
```java
import com.openhft.affinity.Affinity;

Thread t = Thread.currentThread();
Affinity.setAffinity(1); // Pin to core 1
```

### 3. In-Application (C++)
```cpp
#include <sched.h>
cpu_set_t set;
CPU_ZERO(&set);
CPU_SET(1, &set);
pthread_setaffinity_np(pthread_self(), sizeof(set), &set);
```

### 4. Systemd Service
```ini
[Service]
CPUAffinity=1-15
```

## Verification

```bash
# Check isolated cores
cat /proc/cmdline | grep isolcpus

# Check process affinity
taskset -c -p <PID>

# Monitor context switches
perf stat -e context-switches,cpu-migrations <command>
```

## When to Apply

- Single application per server
- Well-designed thread management
- Bare metal only

## Troubleshooting

- App threads not pinning: Check thread count vs available cores
- Performance degradation: Ensure cores are truly isolated
- Context switches high: Verify isolcpus applied correctly

See concepts/cpu-isolation.md for deeper understanding.
