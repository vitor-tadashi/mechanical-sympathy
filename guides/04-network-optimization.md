# Guide 04 — Network Optimization (NIC, Interrupts, Segmentation)

> **Script:** [`scripts/04-network`](../scripts/04-network) · **Concept:** [concepts/network-tuning.md](../concepts/network-tuning.md) · **Example:** [examples/network-segmentation-example.md](../examples/network-segmentation-example.md) · **Previous:** [Guide 03](03-huge-pages-configuration.md) · **Next:** [Guide 05 — cgroups](05-cgroup-isolation.md)

| | |
|---|---|
| **Risk level** | **3 / 5**. All changes are runtime changes and are undone by a reboot, but changing queues or rings resets the NIC. On the wrong interface (the one you are SSH'd through), that is a short outage. |
| **Reboot required** | No. **Not persistent** either: re-applied at boot by `lowlat-runtime.service`. |
| **Applies to** | Bare metal: everything. VMs: coalescing/offloads where the virtual NIC supports them, and IRQ affinity for virtio/SR-IOV queues. |
| **Depends on** | [Guide 02](02-cpu-core-isolation.md) (CPU layout, irqbalance disabled) |

---

## 1. Where network latency hides

A packet arriving on the wire goes through the following stages before the application reads it (details in [concepts/network-tuning.md](../concepts/network-tuning.md)):

```
wire ─► NIC MAC ─► RX ring (DMA to host memory) ─► [interrupt coalescing timer] ─► hard IRQ on CPU X
     ─► NAPI poll in softirq on CPU X ─► GRO/IP/UDP/TCP ─► socket queue ─► wake/poll by the app thread on CPU Y
```

Each stage has a setting that trades latency against throughput or CPU cost:

| Stage | Default behaviour | Latency cost | Setting |
|---|---|---|---|
| Interrupt coalescing | Wait up to *N* µs, or *M* frames, before raising the IRQ. Often **adaptive**. | +10 to +100 µs per packet at low rates | `ethtool -C` |
| Receive aggregation (GRO/LRO) | Merge consecutive TCP segments | small, variable | `ethtool -K` |
| Transmit segmentation (TSO/GSO) | Build large frames and split them in the NIC or late in the stack | small, variable | `ethtool -K` |
| IRQ / softirq placement | irqbalance picks a CPU, possibly remote or isolated | cross-node cache misses; noise on the isolated CPU | `/proc/irq/N/smp_affinity_list` |
| Flow control | A congested peer can PAUSE our transmitter | up to ms | `ethtool -A` |
| Queue count / RSS | Driver default | flows share queues, so head-of-line blocking | `ethtool -L` |
| Ring size | Driver default (often 512–1024) | drops, then retransmits (TCP: ≥ 200 ms RTO) | `ethtool -G` |

The goal of this guide is that a critical packet **never waits** (coalescing 0, no batching, no PAUSE), is **never dropped** (large rings), and is **processed on a known CPU near the NIC** that is **not** one of the isolated CPUs.

## 2. When to apply

| Situation | Apply? |
|---|---|
| Physical NICs carrying order entry, market data, or a latency-critical backend | **Yes** |
| Bulk links (replication, logs, reports) on the same host | Yes, with the *bulk* profile (§5.9) |
| The management interface you are logged in through | **No.** Role `mgmt` is never touched, except for moving its IRQs off isolated CPUs. |
| VMs with virtio/ENA/vmxnet3 | Partially: see §10 |
| Kernel-bypass NICs | Yes. The kernel side gets one queue; the bypass stack has its own tuning (§7). |

## 3. Network segmentation: give each traffic class its own NIC

Latency-critical traffic should never share a NIC, a queue, an IRQ, or a CPU with bulk traffic. A 50 MB log shipment in front of a 200-byte order is head-of-line blocking at every layer. The reference host uses **five roles**:

```
                                 ┌──────────────────────── host ─────────────────────────┐
  Exchange / clients  ══10/25G══►│ ens1f0  critical  (orders, market data)   IRQ → CPU 1 │  NUMA node 1
  Internal services   ══10/25G══►│ ens1f1  critical  (backend, risk, IPC)    IRQ → CPU 1 │  (same card, same node
                                 │                                                        │   as the isolated CPUs)
  Grandmaster clock   ════1G════►│ eno1    timing    (PTP)                   IRQ → CPU 0 │  node 0
  Storage / replicas  ══10G═════►│ ens2f0  bulk      (replication, archive)  IRQ → CPU 30│  node 0
  Log/metrics sinks   ══10G═════►│ ens2f1  bulk      (logs, reports)         IRQ → CPU 30│
  Ops network         ════1G════►│ eno2    mgmt      (SSH, config mgmt)      IRQ → CPU 0 │  untouched
                                 └────────────────────────────────────────────────────────┘
```

| Role | Examples | Coalescing | Offloads | txqueuelen | IRQ CPUs |
|---|---|---|---|---|---|
| **critical** | order entry, market data, critical backend | 0 µs, adaptive off | TSO/GSO/LRO off | default | node-local **housekeeping** CPU |
| **timing** | PTP (hardware timestamping) | 0 µs, adaptive off | off | default | housekeeping CPU |
| **bulk** | replication, logging, reports | 0 µs (reference) or 50–100 µs | off (reference) or on | **large** (300000 in the reference) | a CPU on the *other* node |
| **mgmt** | SSH, monitoring, config management | untouched | untouched | untouched | any housekeeping CPU |

In `lowlat.conf` the roles are one line per interface:

```bash
NICS=(
  "ens1f0|critical|1|0"          # name|role|irq_cpus|txqueuelen (0 = driver default)
  "ens1f1|critical|1|0"
  "eno1|timing|0|0"
  "ens2f0|bulk|30|300000"
  "ens2f1|bulk|30|300000"
  "eno2|mgmt|0|0"
)
```

The scripts never hard-code interface names. The naming scheme (`em1`/`p1p1` biosdevname, `eno1`/`ens1f0` predictable names) differs between vendors and can change with a kernel argument ([Guide 01 §5.7](01-grub-bootloader-tuning.md#57-miscellaneous)).

A full walkthrough, including routing, `tc`, and NetworkManager persistence, is in [examples/network-segmentation-example.md](../examples/network-segmentation-example.md).

## 4. Discovery

```bash
ip -br link                                            # names and state
ethtool -i ens1f0                                      # driver, firmware, PCI bus-info
cat /sys/class/net/ens1f0/device/numa_node             # which node the card is attached to
lspci -vv -s $(ethtool -i ens1f0 | awk '/bus-info/{print $2}') | grep -E 'LnkSta|NUMA'   # PCIe width/speed

ethtool -l ens1f0      # queues (channels): maximum vs current
ethtool -c ens1f0      # coalescing
ethtool -k ens1f0      # offload features
ethtool -a ens1f0      # pause frames
ethtool -g ens1f0      # ring sizes: maximum vs current
grep ens1f0 /proc/interrupts                           # IRQ per queue and which CPUs served them
```

Save this output **before** tuning (`scripts/04-network` has `show_nic_state <iface>` for a compact version). It is your rollback reference.

## 5. Per-NIC settings (`tune_nic_low_latency`)

### 5.1 Queues (channels): `ethtool -L`

```bash
ethtool -L ens1f0 combined <max>     # kernel stack: all hardware queues
ethtool -L ens1f0 combined 1         # kernel-bypass NIC: one queue for the kernel
```

A "combined" channel is an RX + TX queue pair with its own MSI-X interrupt. With the kernel stack, more queues let RSS spread flows, so a burst on one flow does not delay another. Every queue then gets its IRQ placed on the housekeeping CPUs (§6).

With **kernel bypass** (§7), the user-space stack drives the data path directly and the kernel only sees control traffic (ARP, unaccelerated sockets). One queue means one IRQ to place and less memory pinned by the driver.

**Changing channels resets the NIC** on most drivers (link down for 1–3 s). Do it at boot or in a maintenance window, never during trading.

### 5.2 Adaptive coalescing off: `ethtool -C adaptive-rx off adaptive-tx off`

Adaptive (DIM) coalescing re-tunes `rx-usecs` continuously from the observed packet rate. It is excellent for throughput and CPU usage, and it is the reason a quiet link suddenly adds 30–50 µs when a burst starts. It also **overwrites** fixed values, so it must be off before §5.3 means anything.

### 5.3 Coalescing 0: `ethtool -C rx-usecs 0 tx-usecs 0`

`rx-usecs` is how long the NIC waits after the first packet before raising the interrupt, hoping to batch more. `0` means **interrupt immediately**.

| rx-usecs | Latency added at low rate | Interrupt rate at 1 Mpps |
|---|---|---|
| 0 | ~0 | up to 1 M/s (the CPU handling the IRQs must keep up) |
| 8 | ≤ 8 µs | ≤ 125 k/s |
| 50 | ≤ 50 µs | ≤ 20 k/s |
| adaptive | 0–100+ µs, varying | varies |

`tx-usecs 0` does the same for TX completions, so the TX ring is cleaned promptly and never fills. Some drivers also have `rx-frames`/`tx-frames`. If `ethtool -c` shows them, set them to `1` (or `0` where the driver documents that as "disabled").

The cost is CPU: every packet raises an interrupt on the housekeeping CPU. That CPU must not be one of the isolated ones (§6), and it should be **dedicated** to the critical NICs' interrupts on a busy host.

### 5.4 Pause frames off: `ethtool -A autoneg off rx off tx off`

This is **flow control** (IEEE 802.3x PAUSE), not an offload. With RX pause on, a peer or switch whose buffers are filling can tell our NIC to **stop transmitting** for up to 65,535 quanta: about 3.3 ms at 10 GbE and 0.3 ms at 100 GbE. For low-latency traffic a drop, handled by the protocol, is preferable to a silent multi-millisecond stall of *all* traffic on the port. Make sure the switch port is configured the same way. Priority flow control (PFC, for RoCE) is a separate topic and should not be disabled blindly on RDMA fabrics.

### 5.5 Segmentation and aggregation offloads off: `ethtool -K tso off gso off lro off`

| Feature | Direction | What it does | Why off |
|---|---|---|---|
| TSO | TX | NIC splits a large TCP buffer into MSS-sized segments | Encourages the stack to build large buffers; small writes may wait |
| GSO | TX | Same, done in software late in the stack | Same |
| LRO | RX | NIC merges segments into one large packet (not in routing/bridging setups) | Adds merge delay, and hides per-packet timing |

**GRO** (software receive aggregation) is left on by the reference configuration, because it only merges packets that arrive in the same NAPI poll. With coalescing 0 there is rarely more than one packet per poll. If you see GRO in latency traces, add `gro off` for critical NICs.

### 5.6 Checksum offload: keep it on, unless you have measured otherwise

`ethtool -K rx off tx off` disables **checksum offload** and moves checksum computation to the CPU. Some tuning scripts do this together with the offloads above. It is **not** a general latency win: the NIC computes checksums at line rate for free, while the CPU spends cycles on every byte. The only cases where turning it off makes sense are specific NIC/driver bugs, or packet-capture setups that need the raw checksum. It is therefore **opt-in** here (`NIC_DISABLE_CSUM_OFFLOAD=yes`).

### 5.7 Ring sizes at maximum: `ethtool -G rx <max> tx <max>`

The RX ring is where the NIC DMAs packets before software picks them up. If a burst (market open, a reconnect storm, a GC-less but busy consumer) arrives faster than NAPI drains it, packets are **dropped in hardware**, and a dropped TCP segment costs a retransmit timeout of ≥ 200 ms. A larger ring does not add latency while it is empty. It only absorbs bursts. Watch `ethtool -S <iface> | grep -iE 'drop|miss|fifo|no_buf'`.

### 5.8 `txqueuelen` (bulk NICs)

`txqueuelen` is the length of the **qdisc queue** in front of the TX ring (default 1000 packets). The reference configuration leaves critical NICs at the default and raises bulk NICs to **300000**, so that large replication or log bursts are queued instead of dropped at the qdisc.

It has nothing to do with `net.core.netdev_max_backlog`, which is an **RX-side** per-CPU queue between the driver and the protocol stack ([Guide 06](06-kernel-sysctl-tuning.md)). Some scripts claim the two "must be equal"; they don't.

### 5.9 Bulk profile

The reference configuration applies coalescing 0 to *all* non-management NICs, which keeps the rules simple. On hosts where the bulk links are busy, set `NIC_BULK_COALESCE_USECS=50` (or re-enable adaptive coalescing) to cut the interrupt load on the CPU that serves them. Bulk IRQs go to a CPU on the **other** NUMA node, so they compete neither with the critical IRQs nor with the isolated CPUs.

### 5.10 Do not bounce the link

`ethtool -L` and `-G` already reset the queues inside the driver. There is no need for `ifdown`/`ifup`, which relies on legacy network-scripts that were removed in RHEL 9. If a profile change needs re-applying, use `nmcli device reapply <iface>`, and never on the interface you are connected through.

## 6. Interrupt affinity (`set_nic_irq_affinity`)

### 6.1 Choosing the CPU

Where the NIC interrupt runs is where the **softirq** (protocol processing) runs. There are three models:

| Model | IRQ + softirq on | App thread | Pros | Cons |
|---|---|---|---|---|
| **A. Housekeeping IRQ CPU** (reference) | a node-local, non-isolated CPU (CPU 1) | isolated CPU, spins on the socket (non-blocking `recv` in a loop) | Isolated CPU never interrupted. Deterministic. | One cache-line transfer (same node, ~40–80 ns) from CPU 1 to the app CPU per packet |
| **B. Busy polling** | NAPI is polled **from the app thread's syscall** (`SO_BUSY_POLL`, `net.core.busy_read`) | isolated CPU | Skips the IRQ → softirq → wake-up chain | CPU cost; the IRQ still fires unless deferred (`napi_defer_hard_irqs`) |
| **C. Kernel bypass** (§7) | none for data (user space polls the NIC) | isolated CPU | Lowest latency, no syscalls | Vendor stack, own tuning, huge pages |

Never put the IRQs of a kernel-stack NIC **on an isolated CPU** that runs a spinning thread. The softirq then has to preempt your thread (or waits in `ksoftirqd` behind it, see [Guide 02 §6.5](02-cpu-core-isolation.md#65-real-time-scheduling-class-usually-unnecessary)).

Rules for the reference host:

- critical NICs (node 1) → **CPU 1**, the node-1 housekeeping CPU;
- timing/management NICs → CPU 0;
- bulk NICs → CPU 30 (node 0, away from everything critical).

### 6.2 How the script finds and moves the IRQs

```bash
ls /sys/class/net/ens1f0/device/msi_irqs          # exact list of the PCI function's MSI-X vectors
echo 1 > /proc/irq/<irq>/smp_affinity_list         # CPU list format, no hex masks
cat /proc/irq/<irq>/effective_affinity_list        # what the interrupt controller actually uses
```

- The MSI-X directory lists **exactly** the vectors of that PCI function. The fallback, matching names in `/proc/interrupts`, uses whole-word matching, so that `em1` does not also match `em10`, a bug that affects scripts using `grep em1`.
- `smp_affinity_list` takes a CPU list (`1`, `0-3`, `1,3`), so there is no hex-mask arithmetic that silently breaks above 64 CPUs.
- With a multi-CPU list, most interrupt controllers (x86 APIC in physical mode) deliver to **one** CPU of the set. Check `effective_affinity_list`.
- Some drivers on newer kernels use **kernel-managed** IRQs, whose affinity is fixed and `write` fails with `EIO`. The script logs these and continues. For those drivers, reduce the queue count (§5.1) so the managed spreading only covers housekeeping CPUs, or use `isolcpus=managed_irq,...` ([Guide 01](01-grub-bootloader-tuning.md)).

**irqbalance must be off** ([Guide 02 §4.3](02-cpu-core-isolation.md#43-irqbalance-persistent)), or it will rewrite these files within 10 seconds.

### 6.3 RPS, RFS and XPS

- **RPS/RFS** (software steering of receive processing to another CPU through an IPI): **off** (`rps_cpus = 0`, the default) for critical NICs. It adds an IPI and a cross-CPU hop.
- **XPS** (TX queue selection by sending CPU): map each isolated CPU that sends to one TX queue whose completion IRQ is on the housekeeping CPU, for example `echo 2a > /sys/class/net/ens1f0/queues/tx-0/xps_cpus`. This avoids TX-queue lock contention between threads. It is optional, and it is useful when several pinned threads send on the same NIC.

## 7. Kernel bypass (optional)

Kernel-bypass stacks (for example OpenOnload/EF_VI, VMA/XLIO, DPDK-based stacks) map the NIC's queues into the application's address space. A socket-compatible stack intercepts socket calls through `LD_PRELOAD`, so unmodified binaries run as `<bypass-launcher> --profile=<name> java ...`. The application thread polls the NIC directly, with no interrupts, no softirq, and no syscalls. Typical one-way latency drops from ~5–10 µs (tuned kernel stack) to ~1–2 µs.

What changes compared to the kernel-stack configuration:

| Area | Kernel stack | Kernel bypass |
|---|---|---|
| Kernel queues (`ethtool -L`) | maximum | **1** (kernel only carries control traffic) |
| IRQ placement | critical | still do it, for the one remaining queue |
| Driver module options | defaults | limit kernel RSS to the local node / one CPU (vendor options such as `rss_cpus=1`, `rss_numa_local=1` in `/etc/modprobe.d/`) |
| Huge pages | optional | **required** for packet buffers ([Guide 03](03-huge-pages-configuration.md#54-other-huge-page-consumers-in-a-java-stack)). Configure the stack to *fail* without them. |
| Spinning | application | the stack spins inside blocking calls (profile settings like "poll forever", "spin in select/epoll") |
| Pre-allocation | n/a | pre-allocate and pre-fault packet buffers at start-up |
| Launch | `java ...` | `<bypass-launcher> -p <profile> java ...`. Make the launcher add the prefix only when the bypass runtime is installed. |

In `lowlat.conf`, set `KERNEL_BYPASS_DRIVER` (as shown by `ethtool -i`) and `KERNEL_BYPASS_COMMAND`. The script then applies the single-queue profile to those NICs only.

After loading module options, reload the stack's drivers **pinned to a housekeeping CPU** (for example `numactl --physcpubind=1 <bypass-tool> reload`), so the kernel threads it creates start on that CPU.

## 8. Persistence

Nothing in this guide survives a reboot or a driver reload. Two supported ways to re-apply it:

**A. Oneshot unit (default, used by `apply-all`)**: `scripts/systemd/lowlat-runtime.service` runs after `network-online.target` and calls `04-network --runtime` (and the other runtime parts). One script, one place, and it reads the same `lowlat.conf`.

**B. NetworkManager `ethtool.*` properties (RHEL 9)**: NetworkManager applies them every time the connection comes up, including after a link flap:

```bash
nmcli connection modify ens1f0 \
  ethtool.coalesce-adaptive-rx off ethtool.coalesce-adaptive-tx off \
  ethtool.coalesce-rx-usecs 0 ethtool.coalesce-tx-usecs 0 \
  ethtool.pause-autoneg off ethtool.pause-rx off ethtool.pause-tx off \
  ethtool.feature-tso off ethtool.feature-gso off ethtool.feature-lro off \
  ethtool.ring-rx 4096 ethtool.ring-tx 4096
nmcli connection up ens1f0        # maintenance window: re-activates the link
```

Channel counts (`ethtool.channels-combined`) need a recent NetworkManager (≥ 1.36). IRQ affinity is not a NetworkManager property, so keep the oneshot unit for it. `/etc/rc.d/rc.local` also works, but it is a legacy mechanism with no ordering guarantees and no status in `systemctl`.

## 9. Verification

```bash
scripts/04-network --verify             # per-NIC PASS/FAIL, and "no NIC IRQ on an isolated CPU"
. scripts/04-network && show_nic_state ens1f0

# Interrupts: the critical NIC's counters increase only in the CPU1 column
watch -d -n1 "grep -E 'CPU|ens1f0' /proc/interrupts"

# Drops: hardware, driver, and per-CPU backlog
ethtool -S ens1f0 | grep -iE 'drop|miss|discard|no_buf|fifo' | grep -v ': 0$'
awk '{printf "cpu%-3d processed=%d dropped=%d squeezed=%d\n", NR-1, strtonum("0x"$1), strtonum("0x"$2), strtonum("0x"$3)}' /proc/net/softnet_stat
nstat -az | grep -E 'UdpRcvbufErrors|TcpExtListenDrops|TcpExtTCPBacklogDrop'

# Round-trip latency between two tuned hosts (sockperf is in EPEL)
sockperf server -i <ip> -p 11111 --tcp            # on host B (pinned: taskset -c 9)
sockperf ping-pong -i <ip> -p 11111 --tcp -t 30 --full-rtt   # on host A (taskset -c 9)
```

Record p50/p99/p99.9 before and after. The biggest visible change is usually in p99 and above, where adaptive coalescing and PAUSE frames lived.

## 10. Bare metal vs VM

| | Bare metal | VM |
|---|---|---|
| Coalescing 0, adaptive off | ✅ | ⚠️ virtio: `ethtool -C` is supported on recent kernels; ENA/vmxnet3: partial. Try it and check `ethtool -c`. |
| Offloads off | ✅ | ✅ |
| Pause frames | ✅ | ❌ not applicable (the host owns the physical port) |
| Rings / channels | ✅ | ⚠️ limited by the virtual device |
| IRQ affinity | ✅ | ✅ for virtio/SR-IOV queues. irqbalance stays **on** in VMs (Guide 02 keeps it), so either ban CPUs in its config or accept that it moves IRQs. |
| Kernel bypass | ✅ | Only with SR-IOV VF passthrough of a supported NIC |
| Best VM option | — | Ask for **SR-IOV / passthrough** of the critical NIC, plus vCPU pinning on the host |

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ethtool -C` → *Operation not supported* | Driver does not implement that parameter | Check `ethtool -c` for supported keys; skip it |
| Settings revert after a few minutes | irqbalance (IRQ), adaptive coalescing (usecs), NetworkManager re-applying a profile | Disable irqbalance; `adaptive-rx off`; put the values in the NM profile |
| Settings gone after reboot/link flap | Runtime-only | `systemctl status lowlat-runtime`; NM `ethtool.*` properties |
| IRQ affinity write fails with *Input/output error* | Kernel-managed IRQ | §6.2 |
| Interrupt counts rise on an isolated CPU | IRQ not placed (new queue after `ethtool -L`, or a device not in `NICS`) | Run `04-network --runtime` after any channel change; add the device |
| `softnet_stat` squeezed column increasing | The IRQ CPU cannot keep up (coalescing 0 at a high packet rate) | Dedicate that CPU to IRQs, spread the queues over two housekeeping CPUs, or use busy polling / bypass |
| Latency better but throughput collapsed on bulk NIC | Coalescing 0 + offloads off at a high rate | §5.9 bulk profile |
| SSH session dropped while applying | `ethtool -L`/`-G` on the management NIC | Mark it `mgmt` in `NICS` |

## 12. Rollback

```bash
sudo systemctl disable lowlat-runtime.service
sudo systemctl reboot                                   # drivers load with their defaults
# or, per interface, without a reboot:
sudo ethtool -C ens1f0 adaptive-rx on adaptive-tx on
sudo ethtool -K ens1f0 tso on gso on
sudo ethtool -A ens1f0 autoneg on rx on tx on
sudo systemctl enable --now irqbalance
```

## 13. References

- `man 8 ethtool`; kernel networking scaling: <https://docs.kernel.org/networking/scaling.html>
- NAPI and busy polling: <https://docs.kernel.org/networking/napi.html>
- Red Hat — *Tuning the network performance* (RHEL 9), *nm-settings-nmcli(5)* `ethtool` section
- Deep dive: [concepts/network-tuning.md](../concepts/network-tuning.md)
