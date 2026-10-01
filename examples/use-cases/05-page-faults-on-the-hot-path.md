# Use case 5 — Page faults on the hot path

> Guide: [03 Huge pages](../../guides/03-huge-pages-configuration.md) · Script: [`03-huge-pages`](../../scripts/03-huge-pages) · Concepts: [huge pages and NUMA](../../concepts/huge-pages.md), [memory reclaim and faults](../../concepts/memory-reclaim.md#7-faults-what-a-missing-page-costs) · Example: [Java on a tuned host](../hugepages-java-example.md)

## At a glance

- **Situation:** a JVM is slow for its first minutes, and its tail never quite settles, even on a pinned, isolated CPU.
- **Cause:** memory is mapped, not allocated. Every first touch of a page is a fault that allocates and zeroes it, in the middle of serving.
- **Fix:** reserve explicit huge pages per NUMA node at early boot, and pre-touch the heap at start-up. Keep transparent huge pages off.

**Time:** ~30 min + one reboot · **You need:** [Use case 2](02-critical-and-non-critical.md) applied, because the flags only make sense with pinned threads.

> [!NOTE]
> **Illustrative.** The costs are the ones in the [huge pages concept](../../concepts/huge-pages.md#3-page-faults): a minor fault on 4 KiB costs about 0.5 to 2 µs, and zeroing a 2 MiB page 50 to 100 µs. Measure your own host.

## 1. Situation

A 16 GiB heap is committed in pieces. The first access to each page raises a fault, and the kernel allocates a physical page from the local node, zeroes it, and installs the mapping. Then, on a busy host, allocation can fall into direct reclaim or compaction, which costs milliseconds. All of it happens on the thread that touched the page.

<img src="../../assets/diagrams/page-fault-hotpath.svg" alt="Animation: with default first-touch memory six page faults stall an event-loop thread while it serves; with pre-touched huge pages all the faults happen at start-up and serving has none" width="720">

*The same event loop, with and without pre-touch. The faults do not disappear. They move to start-up, before the first request.*

Transparent huge pages do not fix this. THP allocates on a best-effort basis at fault time and may compact memory synchronously while the thread waits, which is why the kernel argument `transparent_hugepage=never` is part of [Guide 01](../../guides/01-grub-bootloader-tuning.md).

## 2. Diagnose

The shape comes first: a histogram that is slow only at the start points at page faults, JIT and cold caches ([Guide 09 §7](../../guides/09-measuring-latency.md#7-reading-the-results)). Then check whether the heap is on explicit huge pages at all:

```bash
# Did the pool move when the application started? (Free should drop by heap + code cache)
grep -E 'HugePages_(Total|Free|Rsvd|Surp)' /proc/meminfo
# HugePages_Free unchanged after start means the heap is on 4 KiB pages

# Which node did the pages come from?
numastat -p <pid>                                        # the "Huge" row, per node

# Can a JVM with these flags get explicit large pages? (This starts a small new JVM.)
java -Xlog:gc+init -XX:+UseZGC -XX:+UseLargePages -Xms1g -Xmx1g -version 2>&1 | grep -i 'large page'
# expect: Large Page Support: Enabled (Explicit)

# Are the mappings backed by 2 MiB pages?
grep -B11 'KernelPageSize: *2048 kB' /proc/<pid>/smaps | grep -E '^[0-9a-f]+-' | head
```

## 3. Change

Size the pool per node from the reference host: a 16 GiB heap plus about 2 GiB of code cache and buffers is 18 GiB, and with headroom **24 GiB = 12,288 pages of 2 MiB on node 1**, where the critical threads live. Helpers on node 0 get 4 GiB ([Guide 03 §3](../../guides/03-huge-pages-configuration.md#3-sizing-the-pool)):

```bash
HUGEPAGES_PER_NODE=("node0:2048" "node1:12288")
HUGEPAGES_OVERCOMMIT=2048        # a safety margin for tooling, not capacity for the critical process
```

```bash
scripts/03-huge-pages --dry-run
sudo scripts/03-huge-pages --apply       # installs hugetlb-reserve-pages.service
sudo systemctl reboot                    # the boot-time reservation is the one that counts
```

A boot-time `hugepages=N` splits evenly across nodes, so the script writes each node's count from an early-boot unit, before other services fragment memory. Then the launcher adds the flags, only on a host that pins its threads ([Guide 03 §5.2](../../guides/03-huge-pages-configuration.md#52-add-the-large-page-flags-only-when-the-host-is-ready-for-them)):

```text
-Xms16G -Xmx16G                 # the whole heap is committed up front
-XX:+UseZGC
-XX:-ZUncommit                  # never hand memory back to the OS
-XX:+UseLargePages              # explicit huge pages, not THP
-XX:+UseNUMA
-XX:+AlwaysPreTouch             # every fault happens at start-up
```

Bind the process to the critical node, so the whole heap comes from the pool you sized (`exec numactl --membind=1 java ...`).

> [!WARNING]
> If the pool is too small, `AlwaysPreTouch` fails at start-up. That is the point: you find out in the first second, not hours later when the heap grows under load.

## 4. Verify

```bash
scripts/03-huge-pages --verify
for n in /sys/devices/system/node/node*/hugepages/hugepages-2048kB; do
  echo "$n total=$(cat $n/nr_hugepages) free=$(cat $n/free_hugepages)"; done
journalctl -b -u hugetlb-reserve-pages                   # requested vs reserved
# after the application starts: Free on node 1 dropped by about 9,200 pages (18 GiB of heap and code cache)
```

<img src="../../assets/diagrams/tlb-reach.svg" alt="Animation: random reads over a 256 MiB working set; with 4 KiB pages only a tiny slice is inside TLB reach and most reads miss, with 2 MiB pages the whole set is inside reach and every read hits" width="720">

*The second gain of the same change: with 2 MiB pages the TLB covers the working set, and the hot path stops taking page walks.*

## 5. Result

Illustrative:

| | Before | After |
|---|---|---|
| First touch of a page | 0.5 to 2 µs (4 KiB), during serving | at start-up |
| Direct reclaim or compaction on a fault | ms-scale, possible during serving | none: the pool was reserved at boot |
| TLB reach of 2,048 entries | 8 MiB | 4 GiB |
| Cost | none | start-up takes seconds longer, and the pool is unavailable to everything else |

## 6. Roll back

- [ ] Remove the large-page flags from the launcher, or set `affinity.enable=false`, or the JVM will look for a pool that no longer exists
- [ ] `sudo scripts/03-huge-pages --rollback`, then `sudo systemctl reboot`
- [ ] `grep HugePages_Total /proc/meminfo` shows `0`

## 7. Key takeaways

- **A fault is a stall you scheduled by accident.** Pre-touch moves it to a time you chose.
- **Explicit, not transparent.** A pool reserved per node at early boot never compacts on the hot path, and a missing pool fails loudly.
- **The pool has an owner.** Size it per node, and bind the process to the node that has it.
