# Use case 6 — Two sockets, one mistake

> Guides: [02 CPU isolation](../../guides/02-cpu-core-isolation.md), [03 Huge pages](../../guides/03-huge-pages-configuration.md) · Concepts: [huge pages and NUMA](../../concepts/huge-pages.md), [hardware topology](../../concepts/hardware-topology.md) · Example: [Java probe](../java-latency-probe/)

## At a glance

- **Situation:** the latency histogram has two humps, and the host has been tuned correctly everywhere else.
- **Cause:** one critical thread runs on the wrong socket, so it reads memory (or the NIC's buffers) across the interconnect on every cache miss.
- **Fix:** put the thread, its memory and the NIC on the same NUMA node, and check all three.

**Time:** ~15 min to find, minutes to fix · **You need:** `numactl` and `numastat` installed.

> [!NOTE]
> **Illustrative.** The cost is the one stated in [Guide 02 §3](../../guides/02-cpu-core-isolation.md#3-designing-the-cpu-layout): about +60 to 100 ns per remote cache miss. Measure it with the probe below.

## 1. Situation

Two-socket servers are two computers joined by an interconnect. Memory and PCIe slots belong to a socket, and a CPU on the other socket reaches them across the link. One misplaced `net.rx` thread, pinned to CPU 4 (node 0) while the NIC and the memory sit on node 1, is enough to move its whole histogram to the right.

<img src="../../assets/diagrams/numa-locality.svg" alt="Two sockets: a net.rx thread on node 1 reads the NIC's packet buffers locally; the same thread on node 0 crosses the interconnect on every cache miss" width="720">

*The thread, the NIC and the memory belong on the same node. Otherwise every cache miss pays the trip across sockets.*

The signature is in the histogram ([Guide 09 §7](../../guides/09-measuring-latency.md#7-reading-the-results)). A thread that is always on the wrong node shifts every percentile by the same few hundred nanoseconds. A thread whose placement changes, for example from one restart to the next, gives two humps: one per node.

## 2. Diagnose

Three facts, one command each:

```bash
cat /sys/class/net/ens1f0/device/numa_node        # the NIC's node
# expect: 1
lscpu -e=CPU,NODE,SOCKET,CORE                     # which node each CPU is on; siblings share a CORE
numastat -p <pid>                                 # where the process's memory sits, per node
```

Then compare them with where each thread runs:

```bash
. scripts/02-cpu-isolation
show_affinity "$(pgrep -f my-app)"                # TID, allowed CPUs, last CPU, thread name
# the finding: net.rx  allowed={4}  last=4  ->  CPU 4 is on node 0, and the NIC is on node 1
```

You can reproduce the effect in two minutes with the [Java probe](../java-latency-probe/), which measures a core-to-core round trip ([example §6](../hugepages-java-example.md#6-reading-the-output), step 4). Put `ping` and `pong` on the same node, then put one of them on the other node, and watch the round trip change:

```properties
# baseline: both threads on node 1
ping.cpu.affinity=9
pong.cpu.affinity=11
```

Then change the second line, and restart the probe. Java's `Properties` has no inline comments, so keep the comment on its own line:

```properties
# pong on node 0: the interconnect, made visible
pong.cpu.affinity=10
```

<img src="../../assets/diagrams/memory-ladder.svg" alt="A logarithmic ruler from 1 nanosecond to 100 milliseconds with the typical range of a cache hit, DRAM, a page fault, a context switch, the kernel network path, an SMI, reclaim and RT throttling" width="720">

*Where the remote-memory penalty sits: small next to a page fault, but paid on every cache miss.*

## 3. Change

Move the thread into the critical node, and keep its memory there:

```properties
# affinity.properties - was net.rx.cpu.affinity=4
net.rx.cpu.affinity=3
```

```bash
exec numactl --membind=1 java ...        # in the launcher: the heap must come from node 1's pool
```

Then check that the pool on node 1 is big enough for what is now bound to it (`HUGEPAGES_PER_NODE`, [Guide 03 §5.3](../../guides/03-huge-pages-configuration.md#53-make-sure-the-pages-come-from-the-right-node)). If the layout was designed from the [floor plan](02-critical-and-non-critical.md), this mistake should not exist, and the fix is a one-line change.

> [!IMPORTANT]
> Changing node interleaving or SNC/NPS in the BIOS changes the node numbers and the CPU-to-node map. Update `ISOLATED_CPUS`, `OS_CPUS`, `HUGEPAGES_PER_NODE` and `NICS` in `lowlat.conf` afterward ([Guide 00 §4.5](../../guides/00-bios-firmware.md#45-memory-and-numa)).

## 4. Verify

```bash
show_affinity "$(pgrep -f my-app)"       # every critical thread on a node-1 CPU
numastat -p <pid>                        # memory on node 1
scripts/verify-tuning                    # host configuration; it does not look inside your application
```

The histogram shows one hump again. If a second hump survives, look for an SMT sibling sharing the core (`lscpu -e`, and [Guide 00 §4.4](../../guides/00-bios-firmware.md#44-hyper-threading)).

## 5. Result

Illustrative:

| | Before | After |
|---|---|---|
| Thread and memory | node 0 thread, node 1 memory and NIC | all on node 1 |
| Every cache miss | local DRAM plus about 60 to 100 ns | local DRAM |
| Histogram | two humps | one |

## 6. Roll back

- [ ] Restore the previous line in `affinity.properties` and restart the application
- [ ] Remove `numactl --membind=1` from the launcher if the pool on node 1 cannot hold the whole heap

## 7. Key takeaways

- **Three things share a node: the thread, its memory and the NIC.** Check all three, because getting two right hides the third.
- **A second hump is a second path.** Cross-node memory and an SMT sibling are the two usual ones.
- **The probe makes it visible in two minutes.** Move one thread across the interconnect and watch the round trip.
