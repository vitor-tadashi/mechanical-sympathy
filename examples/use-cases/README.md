# Use cases — stories from symptom to result

Each use case follows one path: the **symptom** you see, how to **diagnose** it with commands and the expected output, the **change** with the exact `lowlat.conf` lines and the script, the **result**, how to **verify and roll back**, and the **takeaways**. Read them in any order. Every one links to the guide that explains the settings in depth.

> [!NOTE]
> All figures in these pages are **illustrative**: they come from the mechanism costs stated in the guides, on the fictional reference host of [`lowlat.conf.example`](../../scripts/lowlat.conf.example). They are not benchmark results. Measure your own host ([Guide 09](../../guides/09-measuring-latency.md)).

| # | Use case | Symptom | Guides | Time |
|---|---|---|---|---|
| 1 | [The quiet core](01-the-quiet-core.md) | A clean median, and a comb of spikes on the tail | [01](../../guides/01-grub-bootloader-tuning.md), [02](../../guides/02-cpu-core-isolation.md) | ~30 min + reboot |
| 2 | [Critical and non-critical, side by side](02-critical-and-non-critical.md) | Critical threads share cores with ordinary ones | [02](../../guides/02-cpu-core-isolation.md), [05](../../guides/05-cgroup-isolation.md) | ~45 min |
| 3 | [The noisy neighbor](03-the-noisy-neighbor.md) | Spikes every few seconds, with no cause in the application | [05](../../guides/05-cgroup-isolation.md) | ~30 min |
| 4 | [One NIC, one queue, one CPU](04-one-nic-one-queue-one-cpu.md) | A spinning receive thread is interrupted once per burst | [04](../../guides/04-network-optimization.md) | ~20 min |
| 5 | [Page faults on the hot path](05-page-faults-on-the-hot-path.md) | Slow for the first minutes, and a tail that never settles | [03](../../guides/03-huge-pages-configuration.md) | ~30 min + reboot |
| 6 | [Two sockets, one mistake](06-two-sockets-one-mistake.md) | A histogram with two humps | [02](../../guides/02-cpu-core-isolation.md), [03](../../guides/03-huge-pages-configuration.md) | ~15 min |
| 7 | [The freeze nobody logs](07-the-freeze-nobody-logs.md) | A rare spike, a clean OS log, a clean `osnoise` | [00](../../guides/00-bios-firmware.md), [09](../../guides/09-measuring-latency.md) | ~2 h |
| 8 | [Capstone: stock RHEL to tuned in one afternoon](08-stock-to-tuned-in-one-afternoon.md) | The whole path, with an honest before and after | [00](../../guides/00-bios-firmware.md) to [10](../../guides/10-time-sync.md) | ~half a day |
| 9 | [The two-millisecond burst](09-the-two-millisecond-burst.md) | A few thousand packets lost per upstream batch, with a low average load | [04](../../guides/04-network-optimization.md), [06](../../guides/06-kernel-sysctl-tuning.md) | ~20 min |
| 10 | [Line rate without the kernel](10-line-rate-without-the-kernel.md) | Packets lost all the time, with the rings already at the maximum | [04](../../guides/04-network-optimization.md), [08](../../guides/08-kernel-bypass.md) | ~1 h + window |
| 11 | [The first message after a quiet spell](11-the-first-message-after-a-quiet-spell.md) | Fast under load, slow on the first message after idle | [00](../../guides/00-bios-firmware.md), [01](../../guides/01-grub-bootloader-tuning.md), [07](../../guides/07-os-hygiene.md) | ~30 min + reboot |
| 12 | [The sibling that shares your core](12-the-sibling-that-shares-your-core.md) | A critical thread slows down whenever another thread's batch runs | [00](../../guides/00-bios-firmware.md), [01](../../guides/01-grub-bootloader-tuning.md), [02](../../guides/02-cpu-core-isolation.md) | ~15 min, or ~1 h + reboot |
| 13 | [Turbo, the lottery](13-turbo-the-lottery.md) | Identical hosts with different medians, and a median that creeps up after a reboot | [00](../../guides/00-bios-firmware.md), [09](../../guides/09-measuring-latency.md) | ~2 h |

<img src="../../assets/diagrams/who-wants-my-cpu.svg" alt="Seven sources of interference on a CPU, each paired with the setting that removes it, leading to an isolated CPU that runs one pinned thread uninterrupted" width="720">

*Use cases 1 to 4 remove six of these seven sources, one story at a time. The seventh, kernel workers, is the workqueue mask in [Guide 02 §4](../../guides/02-cpu-core-isolation.md#4-moving-the-operating-system-away).*
