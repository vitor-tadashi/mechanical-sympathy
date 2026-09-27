# Guide 3: Huge Pages Configuration

## Overview

Reduce TLB misses using 2MB or 1GB pages.

## Risk Level: 3/5 (Medium - mostly performance impact)

## Allocation Methods

### 1. GRUB Boot-Time
```
hugepages=1024 default_hugepagesz=2M
```

### 2. Runtime
```bash
echo 1024 > /proc/sys/vm/nr_hugepages
```

### 3. Systemd Service
```ini
[Service]
PrivateTmp=yes
PrivateDevices=no
```

## Java Integration

```bash
# Launch with huge pages
java -XX:+UseTransparentHugePages \
     -XX:+AlwaysPreTouch \
     -Xmx8g -Xms8g MyApp
```

## C++ Integration

```cpp
#include <sys/mman.h>

// Allocate 1GB of huge pages
void* ptr = mmap(nullptr, 1024*1024*1024,
    PROT_READ|PROT_WRITE,
    MAP_ANONYMOUS|MAP_PRIVATE|MAP_HUGETLB|MAP_HUGE_1GB, -1, 0);

// Pre-touch for NUMA locality
memset(ptr, 0, 1024*1024*1024);
```

## Verification

```bash
grep -i hugepages /proc/meminfo
cat /proc/sys/vm/nr_hugepages
```

## When to Apply

- Applications with large memory footprint
- Memory-bound operations
- Bare metal and VMs (with hypervisor support)

## Troubleshooting

- Allocation failures: Check available memory, NUMA layout
- Performance unchanged: Verify app is actually using huge pages
- OOM errors: Reduce huge pages allocation

See concepts/huge-pages.md for TLB impact analysis.
