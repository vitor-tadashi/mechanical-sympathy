# Use case 9 — The two-millisecond burst

> Guides: [04 Network](../../guides/04-network-optimization.md), [06 sysctl](../../guides/06-kernel-sysctl-tuning.md) · Scripts: [`04-network`](../../scripts/04-network), [`06-kernel-sysctl`](../../scripts/06-kernel-sysctl) · Concept: [network buffers](../../concepts/network-buffers.md) · Terms: [Glossary](../../GLOSSARY.md)

## At a glance

- **Situation:** a receiver loses a few thousand packets each time an upstream sends a batch. The average load is low, and every dashboard is green.
- **Cause:** the batch is a **burst** that lasts 1.5 ms and arrives faster than one core drains it. The 512-descriptor RX ring is full after 0.2 ms, and the default socket buffer behind it holds only a few hundred datagrams.
- **Fix:** raise the RX ring to its maximum, size the socket buffer with `rmem_max` and `SO_RCVBUF`, and check that no drop counter moves. Fixing the first queue moves the drops to the second, so check both.

**Time:** ~20 min, no reboot (a ring change resets the link for 1 to 3 s) · **You need:** out-of-band console, a maintenance window, a way to replay one upstream batch.

> [!NOTE]
> **Illustrative.** The interface name, the rates and the burst are made up. The arithmetic is the formula of [Concept: network buffers §3](../../concepts/network-buffers.md#3-burst-math). Only the drop counters on your own host are measurements.

## 1. Situation

The upstream flushes a batch every 3 seconds: 6,000 small packets in 1.5 ms, which is 4 Mpps while it lasts. The receiver's software drains the ring at 1.5 Mpps, so 3,750 packets must wait somewhere for the next 2.5 ms.

<img src="../../assets/diagrams/burst-absorb.svg" alt="Animation: two charts of ring fill over time for the same burst; a ring of 512 descriptors is full after 0.2 ms and about 3,240 packets are dropped, a ring of 4096 peaks at 3,750 and drops nothing" width="720">

*The same burst on a 512-slot ring and on a 4096-slot ring. One batch every 3 seconds is about 2,000 packets per second on average, in both cases, which is why no average-rate graph shows the loss.*

## 2. Diagnose

Read the counters of every stage before and after one batch ([Concept: network buffers §6](../../concepts/network-buffers.md#6-where-did-the-packet-die)):

```bash
IF=ens1f0
ethtool -g $IF
# Pre-set maximums:            RX: 8160
# Current hardware settings:   RX: 512        <- the driver default is far below the maximum

ethtool -S $IF | grep -E 'rx_missed_errors|rx_no_buffer_count' > /tmp/before
nstat -n                                      # reset nstat's delta base
# ... replay one upstream batch ...
ethtool -S $IF | grep -E 'rx_missed_errors|rx_no_buffer_count' > /tmp/after
paste -d' ' /tmp/before /tmp/after | awk '{ print $1, "+" ($4 - $2) }'   # after minus before, so old counts do not matter
# rx_missed_errors: +3238            <- the ring dropped 3,238 packets in this one batch
nstat | grep -E 'UdpRcvbufErrors'
# (no output)                        <- the socket did not overflow, because the ring was upstream of it
```

The number is the diagnosis. The ring holds 512 packets, the burst brings 6,000 and 2,250 are drained meanwhile, so `6000 − 2250 − 512 = 3238` are lost. When the counter matches the formula, you have found the queue.

## 3. Change

**Step 1: the ring.** [`04-network`](../../scripts/04-network) sets the rings to the hardware maximum, together with coalescing 0 and the other critical-NIC settings ([Guide 04 §5.7](../../guides/04-network-optimization.md#ring-sizes)). The `NICS` entry in `lowlat.conf` does not change:

```bash
scripts/04-network --dry-run | less
sudo scripts/04-network --apply                     # runtime-only, see the note below
ethtool -g ens1f0
# Current hardware settings:   RX: 8160
```

> [!IMPORTANT]
> `04-network` and `06-kernel-sysctl` change runtime state only. `sudo scripts/apply-all --apply` is what installs and enables `lowlat-runtime.service`, which re-applies it at every boot. If you ran only this script, check `systemctl is-enabled lowlat-runtime.service` before you rely on the result ([Guide 04 §8](../../guides/04-network-optimization.md#8-persistence)).

> [!WARNING]
> Changing a ring resets the NIC on most drivers, with the link down for 1 to 3 seconds. Do it in a maintenance window, and never on the interface that carries your SSH session ([Guide 04 §5.10](../../guides/04-network-optimization.md#510-do-not-bounce-the-link)).

**Step 2: the socket buffer.** Replay the batch. The ring counter stays at zero, and the drops appear one queue downstream:

```bash
nstat | grep UdpRcvbufErrors
# UdpRcvbufErrors     1908         <- the socket buffer overflowed
ss -umn 'sport = :5000'
# skmem:(r212992,rb212992,...,d1908)   <- full at 208 KiB, and d counts its drops
```

The ring now hands the whole burst to the socket at 1.5 Mpps, while the application reads 1.0 Mpps. The socket buffer must hold what is left when the last packet arrives, about 2,000 datagrams. At about 2.3 KiB of truesize each, that is 4.4 MiB, and the 208 KiB default holds 92 to 277 ([Concept: network buffers §4](../../concepts/network-buffers.md#4-socket-buffers)). The calculator does this arithmetic for you:

```bash
scripts/size-buffers --ring 8160 --burst-mpps 4 --burst-us 1500 --drain-mpps 1.5 --app-mpps 1
# dropped, stage 2  1908 packets (UdpRcvbufErrors)
# socket buffer     2000 packets, 4608000 B, SO_RCVBUF request 2250 KiB
```

The [buffer simulator](https://vitor-tadashi.github.io/mechanical-sympathy/buffers.html) shows the same run as a chart.

<img src="../../assets/diagrams/rcvbuf-truesize.svg" alt="A 64-byte datagram is charged about 2,304 or 768 bytes; a 208 KiB default buffer holds only 92 to 277 datagrams, 0.09 to 0.28 ms at 1 Mpps, while an 8 MiB buffer holds about 3,640 to 10,920, 3.6 to 10.9 ms; all drawn to scale" width="720">

*Drawn to scale: the default buffer is a sliver next to the tuned one. The values are illustrative.*

```bash
sudo scripts/06-kernel-sysctl --apply               # rmem_max 128 MiB, rmem_default 8 MiB (Guide 06 §4)
sysctl net.core.rmem_max net.core.rmem_default
# net.core.rmem_max = 134217728
# net.core.rmem_default = 8388608
```

A receiver that never calls `setsockopt` now gets 8 MiB, which covers 4.4 MiB. A receiver that sets its own size should ask for at least the 2250 KiB that `size-buffers` prints, because the kernel doubles the request to 4.4 MiB. Asking for 4 MiB (8 MiB after doubling) leaves room for a longer burst. The kernel clamps anything above `rmem_max` without an error.

## 4. Verify

```bash
ethtool -S ens1f0 | grep -E 'rx_missed_errors|rx_no_buffer_count'
nstat | grep -E 'UdpRcvbufErrors'
ss -umn 'sport = :5000'
# replay one upstream batch, then read them again
# expect: rx_missed_errors unchanged, no UdpRcvbufErrors line, and d0 in skmem
```

Then run the replay ten times. A queue that is only just big enough passes once and fails on a bigger batch, so leave headroom: size for twice the largest burst you have seen.

## 5. Result

Illustrative:

| | Before | After |
|---|---|---|
| RX ring | 512 descriptors | 8160 descriptors |
| Time before the ring is full | 0.2 ms | more than the whole burst |
| Packets dropped per batch | about 3,240 in the ring | 0 |
| Socket buffer | 208 KiB, 92 to 277 datagrams | 8 MiB, 3,640 to 10,920 datagrams |
| Latency of a packet while the ring is empty | unchanged | unchanged |
| Latency of the last packet of the burst | not delivered | about 4.5 ms: it waits behind the others |

The last row is the honest cost. The burst is not lost, but its tail waits: the last packet arrives at 1.5 ms and the application, at 1.0 Mpps, reads it at about 6 ms. To shorten that wait, drain faster ([use case 4](04-one-nic-one-queue-one-cpu.md)), because a bigger ring only buys time.

## 6. Roll back

- [ ] Rings: the checklist in [Guide 04 §11](../../guides/04-network-optimization.md#11-rollback), or `sudo ethtool -G ens1f0 rx 512 tx 512` for one interface (this resets the link)
- [ ] Sysctls: `sudo scripts/06-kernel-sysctl --rollback`
- [ ] Whole host: `sudo systemctl disable lowlat-runtime.service` and reboot

## 7. Key takeaways

- **Size the ring to the burst, not to the average.** The average was about 2,000 packets per second. The burst was 4 Mpps for 1.5 ms.
- **The drops move downstream.** After the ring is fixed, the socket buffer is the next queue to overflow, so read both counters.
- **A bigger buffer delays the burst, and does not speed it up.** The last packet still waits for the drain, and only a faster drain shortens that.
