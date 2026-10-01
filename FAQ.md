# FAQ

Short answers, each with a link to the long one.

<details>
<summary><b>Will this make my application faster?</b></summary>

Mostly it makes it **more predictable**. The median (p50) usually improves a little. The tail (p99.9, max) often drops several-fold, because the tuning removes the rare events that interrupt a thread: ticks, interrupts, kernel work, deep sleep states. Measure your own workload before and after. See [Quick start](QUICK_START.md).

</details>

<details>
<summary><b>Is it safe to run on a production host?</b></summary>

Yes, if you follow the order: `--plan`, `--dry-run`, one canary host with a working out-of-band console, then the fleet. Nothing changes without `--apply`, every original file is saved before the first write, and `apply-all --rollback` restores the host. Only the kernel command line can stop a boot, and the console is the way back. See [Safety](SAFETY.md).

</details>

<details>
<summary><b>Can I apply this on a virtual machine?</b></summary>

Partly. The scripts detect a VM and apply only what helps there: the latency subset of the boot arguments, sysctls, OS hygiene, cgroups and NIC settings the virtual NIC supports. CPU isolation inside a guest does not isolate anything from the hypervisor. The biggest wins in a VM come from the host: dedicated physical CPUs, huge-page-backed memory, SR-IOV. See [Quick start, Scenario B](QUICK_START.md#scenario-b-virtual-machine).

</details>

<details>
<summary><b>How many CPUs should I isolate?</b></summary>

One per latency-critical thread, plus one or two spares, all on the NIC's NUMA node. Keep at least one non-isolated CPU on that node for the NIC's interrupts. Typical applications have 5–15 critical threads. See [Guide 02 §3](guides/02-cpu-core-isolation.md#3-designing-the-cpu-layout).

</details>

<details>
<summary><b>My application does not pin its threads. Does isolation still help?</b></summary>

No, it hurts. Nothing is ever scheduled onto an isolated CPU unless it is pinned there, so those CPUs sit idle while your threads compete for the rest. Pin the critical threads first (inside the application, or with `taskset` per thread ID), or skip isolation. See [Guide 02 §6](guides/02-cpu-core-isolation.md#6-pinning-the-application).

</details>

<details>
<summary><b>Will this help an application with hundreds of threads?</b></summary>

Not much. Tuning removes noise that comes from outside the application, and a pool of hundreds of threads that the application does not control makes its own. There is no one-thread-per-CPU layout to protect, so isolation only leaves CPUs idle. Bring the count down to a few threads with known roles first, then tune. See [What tuning cannot do for you](README.md#what-tuning-cannot-do-for-you) and [Guide 02 §2](guides/02-cpu-core-isolation.md#2-when-to-apply).

</details>

<details>
<summary><b>Why is transparent huge pages (THP) off, if huge pages are good?</b></summary>

THP gets huge pages on a best-effort basis, at fault time or in the background, and may compact memory **synchronously** while your thread waits. Explicit huge pages come from a pool reserved at boot: no allocation work on the hot path, and a missing pool fails at start-up instead of silently. See [Guide 03 §2](guides/03-huge-pages-configuration.md#2-transparent-vs-explicit-huge-pages-why-thp-is-off).

</details>

<details>
<summary><b>Is it safe to turn CPU vulnerability mitigations off?</b></summary>

Only on single-tenant hosts that run no untrusted code, in a controlled network, with written approval from your security team. It is opt-in and off by default. See [Guide 01 §5.6](guides/01-grub-bootloader-tuning.md#56-iommu-and-cpu-vulnerability-mitigations-security-sensitive). The cost lands on system calls, interrupts and context switches, so a thread that spins without them gains little; measure first ([concept: security mitigations](concepts/security-mitigations.md)).

</details>

<details>
<summary><b>Why is my host at 100 % CPU and running hot?</b></summary>

`idle=poll`: idle CPUs spin instead of sleeping, so wake-up costs nothing. That is expected. It costs power and heat, so check the datacenter power budget and the fan profile. See [Guide 01 §5.1](guides/01-grub-bootloader-tuning.md#51-latency-subset-bare-metal-and-vms).

</details>

<details>
<summary><b>Why turn irqbalance off?</b></summary>

It rewrites interrupt affinity every 10 seconds by its own rules. It would undo the NIC placement and could put a NIC interrupt on an isolated CPU. See [Guide 02 §4.3](guides/02-cpu-core-isolation.md#43-irqbalance-persistent).

</details>

<details>
<summary><b>Do I need kernel bypass?</b></summary>

Not to start. Tune the kernel path first (Guides 01–07) and measure it. Bypass (Onload, DPDK) takes one-way latency from about 5–10 µs to about 1–2 µs, but it adds a vendor stack, a spinning core per thread, and operational differences. See [Guide 08](guides/08-kernel-bypass.md).

</details>

<details>
<summary><b>Does this work on AMD CPUs?</b></summary>

Most of it does. The examples use Intel names, and the guides note where AMD differs (for example `amd_pstate` instead of `intel_pstate`). AMD-specific advice follows the kernel documentation and is marked "validate on your hardware".

</details>

<details>
<summary><b>What does "validate on your hardware" mean?</b></summary>

The advice follows the vendor or kernel documentation, and this repository does not measure its effect. Treat it as a direction to test on your hardware, not as a recipe. See [AGENTS.md §3](AGENTS.md#3-documentation).

</details>

<details>
<summary><b>How do I undo everything?</b></summary>

Every guide has a rollback checklist in its last sections, every script has `--rollback` where it applies, and every file the scripts touched is saved under `/var/lib/lowlat/factory-settings/`. Boot arguments need a reboot to go away. See [Quick start, "When something goes wrong"](QUICK_START.md#when-something-goes-wrong).

</details>

<details>
<summary><b>The configuration verifies, but latency did not improve. Now what?</b></summary>

A verified configuration is not a measured improvement. Find what still interrupts the thread: `rtla osnoise` on its CPU, `/proc/interrupts` deltas, context switches with `perf stat`, and SMIs with `turbostat`. Also check the application: an unpinned thread, a syscall-heavy loop on a `nohz_full` CPU, or memory on the wrong NUMA node. See [concepts/cpu-isolation §8](concepts/cpu-isolation.md#8-measuring-noise).

</details>

<details>
<summary><b>How do I decide which CPUs to isolate?</b></summary>

Start from the NUMA node of the critical NIC. Isolate the cores of that node except one housekeeping core for the NIC's interrupts, keep CPU 0 and Hyper-Threading siblings together, and leave a spare or two. `scripts/plan-layout` applies those rules to your `lscpu` output, and the [layout explorer](https://vitor-tadashi.github.io/mechanical-sympathy/explorer.html) does the same in a browser. Review the proposal against your thread roles. See [Guide 02 §3](guides/02-cpu-core-isolation.md#3-designing-the-cpu-layout).

</details>

<details>
<summary><b>Should I turn swap off?</b></summary>

On a dedicated latency host, yes, with the agents capped. With swap, a leak anywhere becomes millisecond swap-in stalls in the critical threads, with nothing logged. Without swap, it ends in one logged OOM kill of the process that grew, and `OOMScoreAdjust=-900` keeps the latency service last. Size the host for its peak first. If the host must keep swap, `SWAP_POLICY=protect` keeps the latency services out of it. See [Guide 12](guides/12-memory-pressure.md) and the [swap and OOM concept](concepts/swap-and-oom.md).

</details>

<details>
<summary><b>How do I keep the host tuned after a kernel or firmware update?</b></summary>

Let it check itself. `scripts/11-day2-operations` installs a timer that runs `verify-tuning` daily and 10 minutes after every boot, and a failed run leaves a failed unit. Before rebooting into a new kernel, check that its boot entry kept `isolcpus`, `nohz_full` and `rcu_nocbs`. See [Guide 11](guides/11-day2-operations.md).

</details>

<details>
<summary><b>Are the numbers in the use cases real measurements?</b></summary>

No. They are typical orders of magnitude taken from the guides, or fictional numbers that show a shape, and every page says which. Measure your own host before and after, as [Guide 09](guides/09-measuring-latency.md) describes.

</details>
