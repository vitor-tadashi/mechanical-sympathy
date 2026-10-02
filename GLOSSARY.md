# Glossary — Every Abbreviation, Product and Unusual Word in Plain English

> Used by every page. Related: [INDEX](INDEX.md), [STYLE](STYLE.md), [CHEATSHEET](CHEATSHEET.md).

## At a glance

- **One place to look anything up.** Abbreviations (SMI, NAPI, DDIO), products (Onload, DPDK), concepts (ring buffer, microburst) and everyday words with a special meaning here (pin, spin, tail).
- **Written for readers whose first language is not English.** Short sentences, no idioms, and every term is explained with words that are either common or defined in this page.
- **Every entry answers two questions:** *What is it?* and *Why do I meet it in these guides?* A link goes to the place that uses it.

**Jump to:** [A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) · [H](#h) · [I](#i) · [J](#j) · [K](#k) · [L](#l) · [M](#m) · [N](#n) · [O](#o) · [P](#p) · [Q](#q) · [R](#r) · [S](#s) · [T](#t) · [U](#u) · [V](#v) · [W](#w) · [X](#x) · [Z](#z) · [Everyday words](#everyday-words-with-a-special-meaning-here) · [Units](#units-and-quick-numbers)

## How to read an entry

- **Bold** is the term. Under it, in *italics*, is how to say it when that is not obvious ("NUMA" is said "NEW-ma").
- **Means** starts with the full name when the term is an abbreviation. Then it says what the thing is, in one or two short sentences.
- **Why you meet it here** says where it matters for latency, with a link.
- A word in **[blue link]** inside an entry is defined in this page too.
- Numbers are typical orders of magnitude, not measurements. A microsecond (µs) is one millionth of a second, and a nanosecond (ns) is one thousandth of that. See [Units](#units-and-quick-numbers).

## A–Z

### A

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="ack"></a>**ACK** | **Acknowledgment.** A TCP message from the receiver that says "I have received the data up to this point". | A delayed ACK can add a 40 ms stall together with [Nagle's algorithm](#nagle). [Concept: network tuning §6](concepts/network-tuning.md#6-transmit-path) |
| <a id="acl"></a>**ACL** | **Access Control List.** A list of rules that says who may reach a service. | The host should sit behind a network firewall or ACL when its own packet filter is removed. [Guide 07 §6](guides/07-os-hygiene.md#6-opt-in-removing-host-packet-filtering) |
| <a id="acpi"></a>**ACPI** | **Advanced Configuration and Power Interface.** The standard way firmware describes the hardware and its power states to the operating system. | Idle states (`acpi_idle`), the frequency driver (`acpi-cpufreq`) and a slow clock counter (`acpi_pm`) come from it. [Concept: power and frequency §3](concepts/power-and-frequency.md#3-frequency-p-states-and-who-chooses-them) |
| <a id="acquire-release"></a>**acquire / release** | Memory-ordering rules for two threads. A **release** write makes everything written before it visible to a thread that reads the same variable with an **acquire** read. | It is exactly what a handoff needs, and on x86 it costs no fence. In Java: `VarHandle.setRelease` and `getAcquire`. [Concept: thread handoff §4](concepts/thread-handoff.md#4-memory-ordering-what-the-cpu-and-the-compiler-may-reorder) |
| <a id="adaptive-coalescing"></a>**adaptive coalescing** | The NIC changes its [coalescing](#coalescing) wait time by itself, longer when traffic is heavy and shorter when it is light. It is also called adaptive interrupt moderation. | It is good for throughput, but it adds 30–50 µs to the first packet of a burst. The guides switch it off. [Guide 04 §5.2](guides/04-network-optimization.md#52-adaptive-coalescing-off-ethtool--c-adaptive-rx-off-adaptive-tx-off) |
| <a id="adq"></a>**ADQ** | **Application Device Queues.** An Intel feature of some NICs that gives one application its own set of NIC queues, so other traffic cannot get in its way. | One of the alternatives to full [kernel bypass](#kernel-bypass). [Guide 08 §7](guides/08-kernel-bypass.md#7-other-stacks-briefly) |
| <a id="af-xdp"></a>**AF_XDP** | **Address Family XDP.** A Linux socket type. The NIC driver puts packets straight into memory that the application owns, so most of the kernel network stack is skipped. | A kernel-supported way to bypass most of the stack without a separate driver. [Guide 08 §7](guides/08-kernel-bypass.md#7-other-stacks-briefly) |
| <a id="affinity"></a>**affinity** | The list of CPUs that a thread or an interrupt is allowed to use. "CPU affinity" is for threads, and "[IRQ](#irq) affinity" is for interrupts. | Most of the tuning is choosing affinities. [Guide 02](guides/02-cpu-core-isolation.md) |
| <a id="almalinux"></a>**AlmaLinux** | A free rebuild of RHEL. Its packages match RHEL and it needs no subscription. | CI runs the scripts in an AlmaLinux 10 image, where every package of the guides can be installed. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="arp"></a>**ARP** | **Address Resolution Protocol.** How a host learns the hardware (MAC) address that belongs to an IP address on the same network. | ARP is not accelerated by [Onload](#onload), so it still goes through the kernel. [Guide 08 §5.1](guides/08-kernel-bypass.md#51-how-onload-works) |
| <a id="aspm"></a>**ASPM** | **Active State Power Management.** A [PCIe](#pcie) feature that puts an idle link to sleep. | Waking a sleeping link takes microseconds, so latency hosts turn it off. [Guide 00 §4.7](guides/00-bios-firmware.md#47-pcie-and-devices) |
| <a id="avx-512"></a>**AVX-512** | **Advanced Vector Extensions, 512 bit.** CPU instructions that work on 512 bits of data at once. | On many Intel CPUs, running them lowers the clock of the core for a while, so code after them runs slower. [Concept: power and frequency §4](concepts/power-and-frequency.md#4-turbo-a-clock-that-depends-on-the-weather) |

### B

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="back-pressure"></a>**back pressure** | When a queue is full, the producer is made to wait or slow down, instead of the queue growing or dropping. | It moves the wait upstream. Choose it, a counted drop or a rejection on purpose for every bounded queue. [Concept: queueing §7](concepts/queueing.md#7-bounded-queues-and-back-pressure) |
| <a id="baseline"></a>**baseline** | Latency percentiles and a `verify-tuning` report that you capture **before** any change. Every result is compared with it. | Without a baseline you cannot tell whether a change helped. [Guide 09 §5](guides/09-measuring-latency.md#5-a-measurement-protocol) |
| <a id="bdp"></a>**BDP** | **Bandwidth-delay product.** The link speed times the round-trip time. It is the amount of data that is "in flight" on the path at one moment. | A TCP receive buffer must be at least this big to keep the link full. [Concept: network buffers §4](concepts/network-buffers.md#4-socket-buffers) |
| <a id="bios"></a>**BIOS / UEFI** | **Basic Input/Output System** and **Unified Extensible Firmware Interface.** The first program that runs when a server starts. It sets up the hardware before Linux loads. UEFI is the modern replacement of the BIOS, and people often say "BIOS" for both. | Power, turbo and memory settings live here, and they change every CPU at once. [Guide 00](guides/00-bios-firmware.md) |
| <a id="bls"></a>**BLS** | **Boot Loader Specification.** A standard for boot entries, stored as small files in `/boot/loader/entries`. | On RHEL 8, 9 and 10, the kernel command line lives in these files. [Guide 01 §4](guides/01-grub-bootloader-tuning.md#4-how-the-arguments-are-applied-rhel-8-9-and-10) |
| <a id="bmc"></a>**BMC** | **Baseboard Management Controller.** A small separate computer inside the server, used for remote power, console and hardware alerts. | It can collect hardware errors so that the CPUs do not have to. [Guide 00 §4.6](guides/00-bios-firmware.md#46-system-management-interrupts) |
| <a id="bpf"></a>**BPF** | **Berkeley Packet Filter.** A way to run small, checked programs inside the kernel. | Guide 06 restricts who may load them. [Guide 06 §7](guides/06-kernel-sysctl-tuning.md#7-bpf) |
| <a id="burst"></a>**burst** | Many packets or requests that arrive in a very short time, after a quiet time. | A burst is what fills a buffer. The buffer must hold it until software catches up. [Concept: network tuning](concepts/network-tuning.md) |
| <a id="busy-polling"></a>**busy polling** | The program (or the kernel for it) keeps asking the NIC "is there a packet?" in a loop, instead of sleeping until an [interrupt](#irq) arrives. | It removes the wake-up delay. Kernel busy polling (`SO_BUSY_POLL`) spins only for a set number of microseconds and then sleeps, and a spin loop in your own code keeps one CPU 100% busy. [Concept: network tuning §8](concepts/network-tuning.md#8-busy-polling) |

### C

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="cache-line"></a>**cache line** | The smallest block of memory that a CPU copies between memory and its cache: 64 bytes on x86. | Two threads that write to the same cache line slow each other down ([false sharing](#false-sharing)). [Concept: CPU isolation §5](concepts/cpu-isolation.md#5-caches-and-coherence-the-mechanical-sympathy-part) |
| <a id="ccx"></a>**CCX / CCD** | **Core Complex** and **Core Complex Die.** On AMD EPYC, a CCX is a group of cores that share one L3 cache (4 cores on Zen 2, 8 on Zen 3 and later). A CCD is the chiplet that carries one or two CCXs. | Two threads that hand data to each other are faster inside one CCX, even on the right [NUMA](#numa) node. [Concept: hardware topology §2.2](concepts/hardware-topology.md#22-l3-domains-the-part-most-layouts-forget) |
| <a id="centos-stream"></a>**CentOS Stream** | The public preview of the next RHEL minor release. It is built a little ahead of RHEL. | CI runs the scripts in CentOS Stream 9 and 10 images as an early warning. A failure there does not block a change. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="cfs"></a>**CFS / EEVDF** | **Completely Fair Scheduler** and **Earliest Eligible Virtual Deadline First.** The parts of Linux that choose which thread runs next. EEVDF replaced CFS in kernel 6.6. | [Concept: CPU isolation §2](concepts/cpu-isolation.md#2-the-linux-scheduler-in-one-page) |
| <a id="cgroup"></a>**cgroup** | **Control group.** A Linux feature that puts processes in a group and limits what the group may use: CPUs, memory, disk. | [Guide 05](guides/05-cgroup-isolation.md) uses cgroups to keep the operating system away from the critical CPUs. |
| <a id="chrony"></a>**chrony** | A program that keeps the computer clock correct by asking time servers over the network. | [Guide 10 §6](guides/10-time-sync.md#6-chrony) |
| <a id="chrt"></a>**chrt** | A Linux command that shows or changes the scheduling class and priority of a process or thread, for example `chrt -f -p 1 <tid>` for [FIFO](#fifo) priority 1. | A whole application started under `chrt -f 99` makes every thread real-time, which starves the kernel threads on their CPUs. [Guide 02 §6.5](guides/02-cpu-core-isolation.md#65-real-time-scheduling-class-usually-unnecessary), [use case 14](examples/use-cases/14-the-spinner-that-stalled-the-kernel.md) |
| <a id="clock-ids"></a>**CLOCK_REALTIME / CLOCK_MONOTONIC** | The two main Linux clocks. REALTIME is the wall-clock time and can jump. MONOTONIC counts from boot and never jumps. | Measure durations with MONOTONIC (`System.nanoTime()`), label events with REALTIME. [Concept: clocks and time §4](concepts/clocks-and-time.md#4-which-clock-to-read) |
| <a id="clocksource"></a>**clocksource** | The hardware counter that the kernel reads to keep time: `tsc`, `hpet` or `acpi_pm`. | With `tsc`, a clock read takes tens of ns. With the others it takes about a microsecond. [Concept: clocks and time §3](concepts/clocks-and-time.md#3-the-tsc-and-the-clocksource) |
| <a id="closed-loop"></a>**closed loop** | A load generator that sends a request, waits for the answer, and only then sends the next one. Its send rate follows the answers. | It stops sending during a stall, so it hides the stall from the numbers: [coordinated omission](#coordinated-omission). Good for host noise, wrong for user latency. [Guide 09 §3.3](guides/09-measuring-latency.md#33-coordinated-omission), [use case 19](examples/use-cases/19-the-benchmark-that-lied.md) |
| <a id="cloud-init"></a>**cloud-init** | The program that sets up a cloud image at its first boot: it reads a small configuration (user, files, commands) from a disk or the network. It can also run a script at every boot. | `tools/check-vm` gives each cloud image its SSH key and network setup through cloud-init. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="coalescing"></a>**coalescing** | The NIC waits a short time, or for several packets, before it raises an [interrupt](#irq). One interrupt then serves many packets. | It saves CPU, and it makes the first packet wait. [Guide 04 §5.3](guides/04-network-optimization.md#53-coalescing-0-ethtool--c-rx-usecs-0-tx-usecs-0) |
| <a id="combined-channel"></a>**combined channel** | One NIC receive queue and one transmit queue that share a single interrupt. `ethtool -l` shows how many there are. | Fewer combined channels mean fewer interrupts to place on CPUs. [Guide 04 §5.1](guides/04-network-optimization.md#51-queues-channels-ethtool--l) |
| <a id="compaction"></a>**compaction** | The kernel moves pages around to make a block of free memory that is contiguous, for allocations larger than one page. | When it runs inline (direct compaction), the allocating thread waits for ms. Huge pages reserved at boot avoid it. [Concept: memory reclaim §5](concepts/memory-reclaim.md#5-compaction-free-is-not-enough) |
| <a id="conntrack"></a>**conntrack** | The kernel table that remembers active network connections for packet filtering and address translation. | Reloading rules does not recreate connections lost while filtering modules were removed. [Guide 07 rollback](guides/07-os-hygiene.md#11-rollback) |
| <a id="coordinated-omission"></a>**coordinated omission** | A mistake in measuring. When a system stalls, the load generator also waits, so it never sends the requests that would have been slow. The report then looks better than the truth. | It makes tail latency look small. [Guide 09 §3.3](guides/09-measuring-latency.md#33-coordinated-omission) |
| <a id="cpu"></a>**CPU** | **Central Processing Unit.** In these guides, "CPU" means one logical processor that the operating system can schedule a thread on. With [Hyper-Threading](#smt) on, one physical core shows as two CPUs. | Almost every guide. [Concept: CPU isolation](concepts/cpu-isolation.md) |
| <a id="cpuidle"></a>**cpuidle** | The part of the Linux kernel that puts an idle CPU into a [C-state](#cstate). Its governor guesses how long the CPU will stay idle and picks a deeper state for a longer wait. `/sys/devices/system/cpu/cpu*/cpuidle/` lists the states, their exit latency and how often each was used. | A thread that blocks lets its CPU sleep, and the first message after a quiet spell pays the wake-up. [Use case 11](examples/use-cases/11-the-first-message-after-a-quiet-spell.md) |
| <a id="cpuset"></a>**cpuset** | The [cgroup](#cgroup) controller that lists which CPUs and memory nodes a group may use. | A wrong cpuset can silently take the critical CPUs back. [Guide 05 §4.4](guides/05-cgroup-isolation.md#44-the-cpuset-trap) |
| <a id="cstate"></a>**C-state** | An idle state of a CPU. C0 is running. Deeper states (C1, C6, ...) save power, and they take microseconds to wake from. | Deep idle states add wake-up delay, so latency hosts limit them. [Guide 00 §4.2](guides/00-bios-firmware.md#42-who-controls-the-idle-states) |

### D

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="ddio"></a>**DDIO** | **Data Direct I/O.** *DEE-dee-eye-oh.* An Intel feature. The NIC writes arriving packets into a small part of the CPU's last-level cache, and not into main memory. The CPU then reads them without a slow memory access. | A very large [ring buffer](#ring-buffer) can hold more data than that cache part, and the benefit is lost. Validate on your hardware. |
| <a id="ddp"></a>**DDP** | **Dynamic Device Personalization.** A firmware package (`ice.pkg`) that teaches an Intel E810 NIC more packet types. | [DPDK](#dpdk) on an E810 runs in a reduced "safe mode" without it. [Guide 08 §6.2](guides/08-kernel-bypass.md#62-binding-ports) |
| <a id="deoptimization"></a>**deoptimization** | The JVM throws away compiled code whose assumptions turned out wrong, runs that path in the interpreter, and compiles it again later. | The first rare message can pay it. Warm up with the rare cases too. [Concept: JVM pauses §5](concepts/jvm-pauses.md#5-the-jit-warm-up-and-deoptimization) |
| <a id="dependabot"></a>**Dependabot** | A GitHub service that opens pull requests for newer dependency versions. | It proposes workflow action and Java probe updates for manual review. [Contributing: dependency updates](CONTRIBUTING.md#dependency-updates) |
| <a id="descriptor"></a>**descriptor** | A small record in a [ring buffer](#ring-buffer) that says where one packet buffer is in memory. The NIC reads a receive descriptor to know where to write the next packet. | A ring with 4096 descriptors can hold 4096 packets. [Concept: ethtool §5](concepts/ethtool.md#5--g---g-ring-sizes) |
| <a id="dim"></a>**DIM** | **Dynamic Interrupt Moderation.** The kernel code behind [adaptive coalescing](#adaptive-coalescing). | It rewrites your fixed [coalescing](#coalescing) values unless it is off. [Guide 04 §5.2](guides/04-network-optimization.md#52-adaptive-coalescing-off-ethtool--c-adaptive-rx-off-adaptive-tx-off) |
| <a id="direct-reclaim"></a>**direct reclaim** | Memory reclaim done by the thread that asked for memory, inline, because free memory fell below the min [watermark](#watermark). The thread frees page cache or writes pages back before its allocation can return. | It costs milliseconds on the CPU of the thread that allocates, so latency hosts keep free memory above the min mark. [Guide 06 §8](guides/06-kernel-sysctl-tuning.md#8-virtual-memory), [use case 17](examples/use-cases/17-memory-pressure-on-a-latency-host.md) |
| <a id="dirty-page"></a>**dirty page / writeback** | A page of the [page cache](#page-cache) that holds data written by a program but not yet saved to disk. **Writeback** is the kernel saving it. | Too many dirty pages make a writing thread wait. Dirty pages also cannot be reclaimed until they are written. [Concept: memory reclaim §6](concepts/memory-reclaim.md#6-dirty-pages-and-writeback) |
| <a id="disruptor"></a>**Disruptor (LMAX)** | An open-source Java library and design for passing messages between threads through a pre-allocated ring, with one writer per sequence. | The best-known example of the SPSC and single-writer ideas in these pages. [Concept: thread handoff §2](concepts/thread-handoff.md#2-a-handoff-counted-in-cache-lines) |
| <a id="dma"></a>**DMA** | **Direct Memory Access.** A device (the NIC) writes to or reads from main memory by itself, without the CPU copying the data. | This is how packets get into the [ring buffer](#ring-buffer). [Concept: network tuning §2](concepts/network-tuning.md#2-the-receive-path-step-by-step) |
| <a id="dpdk"></a>**DPDK** | **Data Plane Development Kit.** A library that lets a user-space program drive the NIC directly and poll it, so no interrupt and no system call is needed. | The best-known [kernel bypass](#kernel-bypass) toolkit. [Guide 08 §6](guides/08-kernel-bypass.md#6-dpdk-on-intel-nics) |
| <a id="dram"></a>**DRAM / RAM** | **Dynamic Random-Access Memory,** also called **RAM.** The main memory of the server. About 100 ns away from a CPU, far slower than its cache. | Cache misses go to DRAM. [Guide 02](guides/02-cpu-core-isolation.md) |
| <a id="drift"></a>**drift** | A tuned setting that quietly went back to its old value, for example after an update. | [Guide 11](guides/11-day2-operations.md) |

### E

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="eal"></a>**EAL** | **Environment Abstraction Layer.** The part of [DPDK](#dpdk) that sets up CPUs, huge pages and devices. Its command-line options start every DPDK program. | [Guide 08 §6.3](guides/08-kernel-bypass.md#63-running-a-dpdk-application) |
| <a id="edr"></a>**EDR** | **Endpoint Detection and Response.** A security agent that watches a host. It runs its own threads. | Its threads must be kept off the critical CPUs. [Guide 05 §5](guides/05-cgroup-isolation.md#5-real-world-examples) |
| <a id="eee"></a>**EEE** | **Energy-Efficient Ethernet.** An Ethernet link puts itself to sleep between packets. | Waking the link adds delay, so it is turned off. [Concept: ethtool §14](concepts/ethtool.md#14-physical-layer--s-fec-eee--m) |
| <a id="ef-vi"></a>**ef_vi** | The low-level programming interface of Solarflare (now AMD) NICs. The program owns the queues and the packet buffers and polls them directly. [Onload](#onload) is built on the same hardware idea. | The fastest, and the most work, on Solarflare NICs. [Guide 08 §2](guides/08-kernel-bypass.md#2-the-families-and-which-one-fits-your-card-and-application) |
| <a id="efi"></a>**EFI** | **Extensible Firmware Interface.** The firmware interface that UEFI (see [BIOS / UEFI](#bios)) grew out of. A server that boots with UEFI keeps its boot files on the EFI system partition, mounted at `/boot/efi`. | Guide 01 meets it when it says where GRUB reads its variables on RHEL 8. [Guide 01](guides/01-grub-bootloader-tuning.md) |
| <a id="ena"></a>**ENA** | **Elastic Network Adapter.** The virtual NIC of Amazon's cloud. | Some NIC tuning is only partly possible on it. [Guide 04](guides/04-network-optimization.md) |
| <a id="epb"></a>**EPB** | **Energy Performance Bias.** A CPU setting that says how much to prefer saving power over speed. | Set to "performance". [Guide 00 §4.1](guides/00-bios-firmware.md#41-power-and-performance-profile) |
| <a id="epel"></a>**EPEL** | **Extra Packages for Enterprise Linux.** An extra software repository for RHEL. | Some measurement tools (for example `sockperf`) come from it. [Guide 09 §4](guides/09-measuring-latency.md#4-the-tools-by-question) |
| <a id="epp"></a>**EPP** | **Energy Performance Preference.** With [HWP](#hwp), the hint that tells the CPU how much to prefer saving power over speed (`energy_performance_preference`). | It only matters when the CPU chooses its own clock. The guides turn HWP off instead. [Concept: power and frequency §3](concepts/power-and-frequency.md#3-frequency-p-states-and-who-chooses-them) |
| <a id="epyc"></a>**EPYC** | The name of AMD's server CPU family. | AMD BIOS settings such as [NPS](#snc) apply to it. [Guide 00 §4.5](guides/00-bios-firmware.md#45-memory-and-numa) |
| <a id="ethtool"></a>**ethtool** | The Linux command that talks to the NIC driver: queues, rings, coalescing, offloads, counters. | [Concept: ethtool](concepts/ethtool.md) |
| <a id="evq"></a>**EVQ / RXQ / TXQ** | The three queues of a Solarflare [VI](#vi): the receive queue (RXQ), the transmit queue (TXQ) and the **event queue** (EVQ), which reports that packets arrived or were sent. | A polling thread reads the EVQ. [Concept: network buffers §7.2](concepts/network-buffers.md#72-solarflare-ef_vi-and-onload) |

### F

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="fake-host"></a>**fake host** | A directory that looks like the `/sys`, `/proc`, `/etc` and `/boot` of a RHEL server, plus fake versions of commands such as `systemctl`, `grubby` and `ethtool` that change only that directory. | `tools/check-scripts` runs every tuning script against fake hosts, so each code path is tested without a real server. It cannot prove what a real kernel does. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="false-sharing"></a>**false sharing** | Two threads use two different variables that sit in the same [cache line](#cache-line). Each write by one thread throws the line out of the other thread's cache. | It slows both threads with no visible reason. [Concept: CPU isolation §5](concepts/cpu-isolation.md#5-caches-and-coherence-the-mechanical-sympathy-part) |
| <a id="fec"></a>**FEC** | **Forward Error Correction.** Extra data on a fast Ethernet link that lets the receiver repair bit errors. | It adds about 100 ns per hop. The mode must match the switch. [Concept: ethtool §14](concepts/ethtool.md#14-physical-layer--s-fec-eee--m) |
| <a id="ffm"></a>**FFM** | **Foreign Function and Memory API.** The standard way for Java code to call native functions (JEP 454). | The Java probe uses it to pin threads, and no third-party library is needed. [Java probe](examples/java-latency-probe) |
| <a id="fifo"></a>**FIFO** | **First In, First Out.** A queue where the oldest item leaves first. | A NIC has a small on-chip FIFO before the [ring buffer](#ring-buffer). Counters with "fifo" in the name mean that it overflowed. [Concept: ethtool §11](concepts/ethtool.md#11--s-statistics) |
| <a id="first-touch"></a>**first touch** | A memory page is placed on the [NUMA node](#numa) of the CPU that writes to it first. | It decides where your memory ends up. [Guide 03 §5.3](guides/03-huge-pages-configuration.md#53-make-sure-the-pages-come-from-the-right-node) |
| <a id="fsync"></a>**fsync** | A system call that waits until a file's data is safely on disk. `fdatasync` skips metadata that is not needed to read the data back. | It always waits for the disk: 0.1 ms or more. Batch it on a logger thread, never on the critical thread. [Concept: logging and I/O §3.2](concepts/logging-and-io.md#32-fsync) |

### G

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="g1"></a>**G1** | The default garbage collector of the Java virtual machine ([JVM](#jvm)). | It falls back to normal pages when huge pages are missing. [Guide 03 §5](guides/03-huge-pages-configuration.md#5-java-applications) |
| <a id="gbe"></a>**GbE** | **Gigabit Ethernet.** 10 GbE is a link speed of 10 billion bits per second. | Link speed decides the largest packet rate. See [Mpps](#units-and-quick-numbers). [Guide 04](guides/04-network-optimization.md) |
| <a id="gc"></a>**GC** | **Garbage collection.** The [JVM](#jvm) frees unused objects by itself, and it may pause the program to do so. | A GC pause is a cause of [tail latency](#tail-latency). [Guide 03](guides/03-huge-pages-configuration.md) |
| <a id="governor"></a>**governor** | The Linux policy that chooses a CPU's clock (`performance`, `powersave`, `schedutil`) or its idle state (`menu`, `teo`). | `performance` keeps the clock high all the time; the others follow the load and make a burst wait. [Concept: power and frequency §3](concepts/power-and-frequency.md#3-frequency-p-states-and-who-chooses-them) |
| <a id="grace-period"></a>**grace period** | In [RCU](#rcu), the wait until every CPU has passed a point where it cannot still be reading old data. Only then is the old data freed. | The freeing runs as RCU callbacks, which `rcu_nocbs` moves off isolated CPUs. [Concept: interrupts and deferred work §5](concepts/interrupts-and-deferred-work.md#5-rcu-freeing-memory-later-safely) |
| <a id="gro"></a>**GRO** | **Generic Receive Offload.** The kernel joins several received packets of one flow into one big packet before the stack handles them. | It saves CPU, and it only joins packets that arrive in the same poll. [Guide 04 §5.5](guides/04-network-optimization.md#55-segmentation-and-aggregation-offloads-off-ethtool--k-tso-off-gso-off-lro-off) |
| <a id="grub"></a>**GRUB** | **GRand Unified Bootloader.** The program that loads the Linux kernel and gives it the kernel command line. | [Guide 01](guides/01-grub-bootloader-tuning.md) |
| <a id="grubenv"></a>**grubenv** | A small file of [GRUB](#grub) variables, `/boot/grub2/grubenv`. On RHEL 8 it holds `kernelopts`, the kernel command line that the boot entries point to. | `grub2-mkconfig` can rewrite it. `tools/check-vm` records it before and after the guides run, to show which tool decides the command line. [Guide 01](guides/01-grub-bootloader-tuning.md) |
| <a id="gso"></a>**GSO** | **Generic Segmentation Offload.** The kernel builds one big packet and cuts it into normal-size packets late, just before the driver. | Batching that can add delay. [Guide 04 §5.5](guides/04-network-optimization.md#55-segmentation-and-aggregation-offloads-off-ethtool--k-tso-off-gso-off-lro-off) |

### H

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="hdrhistogram"></a>**HdrHistogram (HDR histogram)** | A library that records latency values in a compact histogram with a fixed precision. | The standard way to record percentiles and to correct [coordinated omission](#coordinated-omission). [Guide 09](guides/09-measuring-latency.md) |
| <a id="host-class"></a>**host class** | What the scripts find out about the host: `bare_metal`, `virtual_machine` or `container`. It decides which steps apply. | [Guide 00 §10](guides/00-bios-firmware.md#10-bare-metal-vs-vm) |
| <a id="housekeeping-cpu"></a>**housekeeping CPU** | A CPU that is *not* isolated: the same set as the [OS CPUs](#os-cpus). The operating system, its background work and the interrupts run there. Two subsets have their own names: the [IRQ CPU](#irq-cpu) of each NIC, and the **slice CPUs** (`HOUSEKEEPING_SLICE_CPUS`), where `housekeeping.slice` fences the agents. | The critical CPUs stay quiet because everything else is sent to the housekeeping CPUs. [Guide 02 §3](guides/02-cpu-core-isolation.md#3-designing-the-cpu-layout) |
| <a id="hpet"></a>**HPET** | **High Precision Event Timer.** A timer chip on the motherboard. Linux can use it as a [clocksource](#clocksource). | It is much slower to read than the [TSC](#tsc). If the kernel falls back to it, every timestamp costs about a microsecond. [Concept: clocks and time §3](concepts/clocks-and-time.md#3-the-tsc-and-the-clocksource) |
| <a id="hrtimer"></a>**hrtimer** | **High-resolution timer.** A kernel timer that fires at an exact time, used by `nanosleep`, timeouts and the scheduler tick. | A thread that sleeps with a timeout arms one on its own CPU, and it fires there. [Concept: interrupts and deferred work §6](concepts/interrupts-and-deferred-work.md#6-workqueues-and-timers) |
| <a id="huge-pages"></a>**huge pages** | Memory pages of 2 MiB or 1 GiB, instead of the normal 4 KiB. One [TLB](#tlb) entry then covers much more memory. | Fewer TLB misses and no page faults on the hot path. [Guide 03](guides/03-huge-pages-configuration.md) |
| <a id="hugetlbfs"></a>**hugetlbfs** | The Linux way to reserve huge pages on purpose, in advance. This is the "explicit" kind, and it is what the guides use. | It is predictable. [THP](#thp) is not. [Guide 03 §2](guides/03-huge-pages-configuration.md#2-transparent-vs-explicit-huge-pages-why-thp-is-off) |
| <a id="hwloc"></a>**hwloc / lstopo** | **Hardware Locality.** A library and a tool (`lstopo`) that draw a machine: sockets, caches, cores, hardware threads, and the PCIe devices under each socket. | The quickest way to see which socket a NIC hangs off. [Concept: hardware topology §4](concepts/hardware-topology.md#4-reading-the-topology-from-a-host) |
| <a id="hwp"></a>**HWP** | **Hardware P-states,** also called Speed Shift. The CPU chooses its own frequency, without asking the operating system. | The frequency can then change at times that you cannot see. [Guide 00 §4.1](guides/00-bios-firmware.md#41-power-and-performance-profile) |
| <a id="hybrid-root"></a>**hybrid root** | A directory used as `LOWLAT_ROOT` in which `/etc`, `/boot`, `/usr` and `/var` are links to the real ones, while `/proc` and `/sys` are a [fake host](#fake-host). | It lets the real `systemctl`, `grubby` and `tuned-adm` see the files that the scripts write, and keeps the kernel fake. Only for a throwaway container. [CONTRIBUTING](CONTRIBUTING.md#workflow) |

### I

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="ibrs"></a>**IBRS / eIBRS / IBPB** | **Indirect Branch Restricted Speculation**, its **enhanced** version, and the **Indirect Branch Predictor Barrier.** CPU controls that stop one program from steering the branch guesses of another. | They protect against Spectre v2. IBPB on a context switch can cost microseconds on older CPUs. [Concept: security mitigations §3](concepts/security-mitigations.md#3-the-families-and-what-the-kernel-does) |
| <a id="icmp"></a>**ICMP** | **Internet Control Message Protocol.** The protocol of `ping` and of network error messages. | [Onload](#onload) does not accelerate it, so it stays in the kernel. [Guide 08 §3](guides/08-kernel-bypass.md#3-what-happens-to-the-kernel-queues-the-combined-question) |
| <a id="idle-poll"></a>**idle=poll** | A kernel option. An idle CPU spins in a loop instead of sleeping. | No wake-up delay, at the price of full power use. [Concept: bootloader §4](concepts/bootloader.md#4-how-the-main-parameters-work) |
| <a id="idle-sibling"></a>**idle sibling** | The [Hyper-Threading](#smt) partner of an isolated core. It is isolated together with its core, and it runs no thread. | [Guide 02 §3](guides/02-cpu-core-isolation.md#3-designing-the-cpu-layout) |
| <a id="ieee"></a>**IEEE** | **Institute of Electrical and Electronics Engineers.** The organization that writes standards such as Ethernet (802.3) and [PTP](#ptp) (1588). | Flow control ([PAUSE](#pause-frame)) is IEEE 802.3x. [Concept: ethtool §8](concepts/ethtool.md#8--a---a-flow-control-pause-frames) |
| <a id="illustrative"></a>**illustrative** | Marks a number that shows a shape and is not a measurement. Every figure in the use cases and diagrams is either illustrative or a typical order of magnitude. | Read such numbers for the idea, and measure your own host. [Use cases](examples/use-cases/README.md) |
| <a id="imissed"></a>**imissed** | A [DPDK](#dpdk) counter: packets that the NIC dropped because the receive ring was full. | It means your polling loop is too slow. [Concept: network buffers §7.1](concepts/network-buffers.md#71-dpdk) |
| <a id="incast"></a>**incast** | Many senders answer one receiver at the same moment, for example after a reconnect. Their packets arrive together on one port. | It creates a large [burst](#burst). [Concept: network buffers §5](concepts/network-buffers.md#5-traffic-shapes-which-queue-saves-you) |
| <a id="infinity-fabric"></a>**Infinity Fabric** | AMD's connection between the parts of a processor (chiplets, I/O die) and between the sockets of a server. | A cache line that moves between two [CCXs](#ccx) or two sockets travels over it and pays its latency. [Concept: hardware topology §2](concepts/hardware-topology.md#2-the-levels-from-a-hardware-thread-to-the-box) |
| <a id="iommu"></a>**IOMMU** | **Input/Output Memory Management Unit.** Hardware that translates and checks the addresses that devices use for [DMA](#dma). | [DPDK](#dpdk) needs it (through [VFIO](#vfio)) to use a NIC safely. [Guide 08 §4](guides/08-kernel-bypass.md#4-prerequisites) |
| <a id="iotlb"></a>**IOTLB** | The cache of the [IOMMU](#iommu), like a [TLB](#tlb) for devices. A miss makes a DMA slower. | Turning the IOMMU off removes these misses, and it removes protection too. [Guide 01 §5](guides/01-grub-bootloader-tuning.md#5-the-parameters-one-by-one) |
| <a id="ipc"></a>**IPC** | **Inter-Process Communication.** How programs on one host exchange data, for example through shared memory, pipes or sockets. | It is a traffic class that can get its own NIC. [Guide 04 §3](guides/04-network-optimization.md#3-network-segmentation-give-each-traffic-class-its-own-nic) |
| <a id="ipi"></a>**IPI** | **Inter-Processor Interrupt.** One CPU interrupts another CPU. | Waking a thread on another CPU costs an IPI. [Concept: network tuning §2](concepts/network-tuning.md#2-the-receive-path-step-by-step) |
| <a id="ipmi"></a>**IPMI** | **Intelligent Platform Management Interface.** The standard way to talk to the [BMC](#bmc). | The out-of-band console (iLO, iDRAC or IPMI) must work before you change BIOS settings, because each change needs a reboot. [Guide 00 §3](guides/00-bios-firmware.md#3-before-you-start) |
| <a id="irq"></a>**IRQ** | **Interrupt Request.** *I-R-Q.* A device (or a timer) stops the CPU that is running a program, and asks it to handle an event first. | Every interrupt on a critical CPU is a delay: 1–5 µs for the interrupt alone, up to ~50 µs with its softirq work and cold caches. [Guide 02 §1](guides/02-cpu-core-isolation.md#1-the-problem-everything-else-that-wants-your-cpu) |
| <a id="irq-cpu"></a>**IRQ CPU** | The housekeeping CPU that a NIC's interrupts are sent to (`irq_cpus` in `NICS`). For a critical NIC it is on the NIC's own NUMA node, and it is never isolated. | CPU 1 on the reference host. Keep bursty work, such as agents, away from it. [Guide 04 §6.1](guides/04-network-optimization.md#61-choosing-the-cpu) |
| <a id="irqbalance"></a>**irqbalance** | A background service that moves interrupts between CPUs on its own. | It undoes your interrupt placement, so it is disabled. [Guide 02 §4.3](guides/02-cpu-core-isolation.md#43-irqbalance-persistent) |
| <a id="isolated-cpu"></a>**isolated CPU** | A CPU that was removed from normal scheduling ([isolcpus](#isolcpus)), has no [tick](#tick) ([nohz_full](#nohz-full)) and has its [RCU](#rcu) callbacks moved away. Only threads that you pin there run on it. | [Guide 02](guides/02-cpu-core-isolation.md) |
| <a id="isolcpus"></a>**isolcpus** | A kernel option that removes CPUs from normal scheduling. Only threads that you pin there will run on them. | The base of [CPU isolation](#housekeeping-cpu). [Concept: bootloader §4](concepts/bootloader.md#4-how-the-main-parameters-work) |

### J

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="jdk"></a>**JDK** | **Java Development Kit.** The [JVM](#jvm) and the tools to build and run Java programs. | [Guide 03 §5](guides/03-huge-pages-configuration.md#5-java-applications) |
| <a id="jep"></a>**JEP** | **JDK Enhancement Proposal.** A numbered document that describes one change to Java. JEP 454 describes the [FFM](#ffm) API. | [Java probe](examples/java-latency-probe) |
| <a id="jfr"></a>**JFR** | **JDK Flight Recorder.** A low-overhead event recorder built into the JVM: GC, safepoints, deoptimization, class loading, locks. | It shows JVM stalls that are not safepoints, at about 1 % cost. [Concept: JVM pauses §7](concepts/jvm-pauses.md#7-seeing-it-logs-and-jfr) |
| <a id="jit"></a>**JIT** | **Just-In-Time compiler.** The [JVM](#jvm) turns hot code into machine code while the program runs. | The first calls are slow, until the code is compiled. Running warm-up traffic before real traffic hides this. [Pre-touch](#pre-touch) does not: it only removes page faults. [Guide 09](guides/09-measuring-latency.md) |
| <a id="jitter"></a>**jitter** | How much the time of an operation changes from one run to the next. Low jitter means a narrow histogram. | This is what the tuning reduces. [Guide 09](guides/09-measuring-latency.md) |
| <a id="journald"></a>**journald** | `systemd-journald`, the systemd service that collects logs: kernel messages, service output and `syslog()` calls. | A program that logs through stdout or `syslog()` can wait when journald is slow. [Concept: logging and I/O §3](concepts/logging-and-io.md#3-where-a-log-line-waits) |
| <a id="jvm"></a>**JVM** | **Java Virtual Machine.** The program that runs Java code. | The reference application is a Java program, so the guides give JVM flags. [Guide 03 §5](guides/03-huge-pages-configuration.md#5-java-applications) |

### K

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="kernel-bypass"></a>**kernel bypass** | The program talks to the NIC directly, from user space. It skips the kernel network stack, the interrupts and the system calls. | Fastest path, and you lose tools like `tcpdump` and the firewall. [Guide 08](guides/08-kernel-bypass.md) |
| <a id="kpti"></a>**KPTI** | **Kernel Page-Table Isolation.** The Meltdown fix: user space runs with page tables that do not map the kernel, so each entry into the kernel switches page tables. | It adds about 100–200 ns to every system call and interrupt on affected Intel CPUs. `pti=off` removes it. [Concept: security mitigations §3](concepts/security-mitigations.md#3-the-families-and-what-the-kernel-does) |
| <a id="ksoftirqd"></a>**ksoftirqd** | A kernel thread, one per CPU. It runs [softirq](#softirq) work when there is too much of it to do inside the interrupt. | If it is busy, packets are waiting. [Concept: network tuning §4](concepts/network-tuning.md#4-napi-softirq-budget-and-ksoftirqd) |
| <a id="kswapd"></a>**kswapd** | The kernel thread (one per NUMA node) that reclaims memory in the background. It wakes when free memory falls below the low [watermark](#watermark) and works until it is above the high one. | When it starts early enough, no application thread has to do [direct reclaim](#direct-reclaim). It runs on the OS CPUs. [Guide 06 §8](guides/06-kernel-sysctl-tuning.md#8-virtual-memory) |
| <a id="kvm"></a>**KVM** | **Kernel-based Virtual Machine.** The virtual-machine support that is built into Linux. | A KVM guest cannot truly isolate CPUs from its host. [Guide 01 §2](guides/01-grub-bootloader-tuning.md#2-when-to-apply-and-when-not-to) |
| <a id="kworker"></a>**kworker** | A kernel thread that runs deferred kernel work from a [workqueue](#workqueue). | It can wake up on any CPU unless you restrict it. [Guide 02 §4.2](guides/02-cpu-core-isolation.md#42-unbound-kernel-workqueues-runtime) |

### L

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="leap-second"></a>**leap second** | A second added to [UTC](#utc) now and then to keep it close to the Earth's rotation. | It steps `CLOCK_REALTIME` by one second, or a server smears it over hours. Durations taken from REALTIME break. [Concept: clocks and time §5](concepts/clocks-and-time.md#5-step-and-slew) |
| <a id="littles-law"></a>**Little's law** | For any stable queue: the number of items in it equals the arrival rate times the average time each item spends in it (L = λ × R). | It turns a queue length into a latency without a single timestamp. [Concept: queueing §2](concepts/queueing.md#2-the-vocabulary) |
| <a id="llc"></a>**LLC** | **Last-Level Cache.** The biggest and slowest CPU cache (usually called L3). On Intel Xeon the cores of a socket share one; on AMD EPYC each [CCX](#ccx) has its own. | [DDIO](#ddio) writes packets here. [Guide 02](guides/02-cpu-core-isolation.md) |
| <a id="log4j"></a>**Log4j 2** | A widely used open-source logging library for Java. Its asynchronous loggers hand each log event to a background thread through a preallocated ring. | An example of the handoff design for logging. Check that it does not allocate per call and that its thread is pinned. [Concept: logging and I/O §4](concepts/logging-and-io.md#4-the-design-hand-off-do-not-write) |
| <a id="lowlat-runtime-service"></a>**lowlat-runtime.service** | The systemd unit that applies all runtime (not persistent) settings again at every boot. | [Guide 11 §2](guides/11-day2-operations.md#2-the-verification-timer) |
| <a id="lowlat-verify-timer"></a>**lowlat-verify.timer** | The timer that runs `verify-tuning` every day and 10 minutes after each boot. The unit fails when a check fails. | [Guide 11 §2](guides/11-day2-operations.md#2-the-verification-timer) |
| <a id="lro"></a>**LRO** | **Large Receive Offload.** The NIC joins received packets into one big packet. | It hides packet boundaries and adds delay, so it is off. [Guide 04 §5.5](guides/04-network-optimization.md#55-segmentation-and-aggregation-offloads-off-ethtool--k-tso-off-gso-off-lro-off) |
| <a id="lru"></a>**LRU** | **Least Recently Used.** The lists the kernel uses to age memory pages. Pages not used for the longest time are reclaimed first. | It decides which pages are evicted, including the program's own code. [Concept: memory reclaim §3](concepts/memory-reclaim.md#3-aging-the-lru-lists) |
| <a id="lychee"></a>**Lychee** | A command-line checker for links and page fragments. | [Documentation health](CONTRIBUTING.md#documentation-health) |

### M

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="mbuf"></a>**mbuf** | **Message buffer.** The [DPDK](#dpdk) structure that holds one packet: a small header and a data area. | A DPDK program runs out of packets when it runs out of mbufs. [Guide 08 §6.1](guides/08-kernel-bypass.md#61-how-it-works) |
| <a id="mds"></a>**MDS / TAA** | **Microarchitectural Data Sampling** and **TSX Asynchronous Abort.** Flaws that leak data left in internal CPU buffers. | The kernel clears those buffers (`VERW`) on every return to user space. [Concept: security mitigations §3](concepts/security-mitigations.md#3-the-families-and-what-the-kernel-does) |
| <a id="mempool"></a>**mempool** | **Memory pool.** In [DPDK](#dpdk), a fixed set of [mbufs](#mbuf) created at start-up in huge pages. Receiving takes one out, and finishing with a packet puts it back. | It is sized once. If it is too small, receiving stops. [Guide 08 §6.1](guides/08-kernel-bypass.md#61-how-it-works) |
| <a id="microburst"></a>**microburst** | A [burst](#burst) so short (microseconds to a few milliseconds) that average-rate graphs do not show it. | It can still overflow a small buffer. [Concept: network tuning](concepts/network-tuning.md) |
| <a id="misspell"></a>**misspell** | A command-line checker for common spelling mistakes, with an American English mode. | [Documentation health](CONTRIBUTING.md#documentation-health) |
| <a id="mitigation"></a>**mitigation** | A kernel workaround for a CPU security flaw (Spectre, Meltdown and others). It costs speed. | Some guides switch them off. That removes a security control, so it is a deliberate decision. [Guide 01 §5](guides/01-grub-bootloader-tuning.md#5-the-parameters-one-by-one) |
| <a id="mlock"></a>**mlock / mlockall** | System calls that pin a process's memory, so the kernel never evicts or swaps those pages. | `mlockall` keeps code and data from major faults. It needs a large enough memlock limit. [Concept: memory reclaim §7](concepts/memory-reclaim.md#7-faults-what-a-missing-page-costs) |
| <a id="mpps"></a>**Mpps** | **Million packets per second.** | The unit for packet rate. See [Units](#units-and-quick-numbers). |
| <a id="msi-x"></a>**MSI-X** | **Message Signaled Interrupts, extended.** A [PCIe](#pcie) device raises an interrupt by writing a message. It can have many vectors, one per queue. | Each NIC queue has its own vector, and you place each on a CPU. [Guide 04 §6](guides/04-network-optimization.md#6-interrupt-affinity-set_nic_irq_affinity) |
| <a id="msr"></a>**MSR** | **Model-Specific Register.** A CPU register for settings and counters, read with root rights through the `msr` kernel module. | `turbostat` reads the SMI counter and the C-state times from MSRs. [Concept: power and frequency §6](concepts/power-and-frequency.md#6-smis-the-firmware-takes-every-cpu) |
| <a id="mss"></a>**MSS** | **Maximum Segment Size.** The largest amount of TCP data in one packet, usually 1460 bytes when the [MTU](#mtu) is 1500. | [TSO](#tso) cuts a large send into MSS-sized pieces. [Concept: ethtool §7](concepts/ethtool.md#7--k---k-offload-features) |
| <a id="mtu"></a>**MTU** | **Maximum Transmission Unit.** The largest packet a link carries, usually 1500 bytes. | It changes the packet rate for a given speed. [Guide 04](guides/04-network-optimization.md) |

### N

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="nagle"></a>**Nagle's algorithm** | TCP holds a small piece of data until the earlier data is acknowledged. | It adds delay. Set `TCP_NODELAY` on latency-critical sockets. [Concept: network tuning §6](concepts/network-tuning.md#6-transmit-path) |
| <a id="napi"></a>**NAPI** | *NAP-ee.* Linux's method for receiving packets: one interrupt starts a polling loop, and the loop takes packets until the [ring buffer](#ring-buffer) is empty. Then interrupts come back on. | It is the software that empties the ring. [Concept: network tuning §4](concepts/network-tuning.md#4-napi-softirq-budget-and-ksoftirqd) |
| <a id="nat"></a>**NAT** | **Network Address Translation.** A device or a kernel module rewrites the addresses in packets. | The optional removal of packet filtering also removes the NAT modules. [Guide 07 §6](guides/07-os-hygiene.md#6-opt-in-removing-host-packet-filtering) |
| <a id="nfs"></a>**NFS** | **Network File System.** A way to mount disks of another server. | Its services are not needed on a latency host, unless it mounts NFS. [Guide 07 §2](guides/07-os-hygiene.md#2-services) |
| <a id="nftables"></a>**nftables** | The Linux packet filtering system managed with the `nft` command. A ruleset contains its tables, chains, and rules. | Save the ruleset before the optional firewall flush and restore it during rollback. [Guide 07](guides/07-os-hygiene.md#11-rollback) |
| <a id="nic"></a>**NIC** | **Network Interface Card.** The hardware that connects the server to the network. | [Guide 04](guides/04-network-optimization.md) |
| <a id="nmi"></a>**NMI** | **Non-Maskable Interrupt.** An interrupt that cannot be switched off. | The NMI watchdog fires a periodic NMI on every CPU, so it is disabled. [Guide 01 §5](guides/01-grub-bootloader-tuning.md#5-the-parameters-one-by-one) |
| <a id="nohz-full"></a>**nohz_full** | A kernel option. It stops the periodic [tick](#tick) on the listed CPUs while only one thread runs there. | A quiet CPU. [Concept: bootloader §4](concepts/bootloader.md#4-how-the-main-parameters-work) |
| <a id="ntp"></a>**NTP** | **Network Time Protocol.** Clock synchronization over the network, accurate to 10–100 µs on a quiet LAN, and to milliseconds over the internet. [chrony](#chrony) speaks it. | [Guide 10 §3](guides/10-time-sync.md#3-chrony-or-ptp) |
| <a id="ntuple"></a>**ntuple rule** | A NIC filter that sends packets that match a pattern to one chosen queue. | It puts one flow on its own queue. [Guide 04 §5.1](guides/04-network-optimization.md#51-queues-channels-ethtool--l) |
| <a id="numa"></a>**NUMA** | **Non-Uniform Memory Access.** *NEW-ma.* A server with several CPU sockets, each with its own memory. Memory of another socket is slower to reach. | Keep the thread, the NIC and the memory on the same node. [Guide 02](guides/02-cpu-core-isolation.md) |
| <a id="nvme"></a>**NVMe** | **Non-Volatile Memory Express.** The fast interface for flash disks on PCIe. | Even from NVMe, a major fault takes about 0.1 ms, which is thousands of memory accesses. [Concept: memory reclaim §8](concepts/memory-reclaim.md#8-numbers-to-remember) |

### O

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="offload"></a>**offload** | Work that the NIC does instead of the CPU, such as checksums or cutting large packets. | Some offloads help, and some add delay. [Concept: ethtool §7](concepts/ethtool.md#7--k---k-offload-features) |
| <a id="onload"></a>**Onload** | A Solarflare (now AMD) software layer. It sits between the program and the kernel, and it runs the TCP/UDP stack in user space over the NIC queues. The program does not change. | The main [kernel bypass](#kernel-bypass) path in these guides. [Guide 08 §5](guides/08-kernel-bypass.md#5-onload-on-solarflare--amd-nics) |
| <a id="oom"></a>**OOM** | **Out Of Memory.** The kernel kills a process because memory ran out. | Reserved huge pages cannot be used by others, which can cause it. [Guide 03 §3](guides/03-huge-pages-configuration.md#3-sizing-the-pool) |
| <a id="oom-score-adj"></a>**oom_score / oom_score_adj** | The [OOM](#oom) killer's score for each process (0–1000), and the adjustment you can add to it (−1000 to +1000). The highest score is killed first. | Give agents a positive value and the latency service `−900`, so it is killed last. systemd sets it with `OOMScoreAdjust=`. [Concept: swap and the OOM killer §5](concepts/swap-and-oom.md#5-the-oom-killer) |
| <a id="open-loop"></a>**open loop** | A load generator that sends on a fixed schedule, whether or not the answers have come back, and times each request from when it was due. | It sees every request a stall delays, as real users do. [Guide 09 §3.3](guides/09-measuring-latency.md#33-coordinated-omission), [use case 19](examples/use-cases/19-the-benchmark-that-lied.md) |
| <a id="os-cpus"></a>**OS CPUs** | All CPUs that are not isolated. This is the same set as the [housekeeping CPUs](#housekeeping-cpu), and it is what systemd's `CPUAffinity` lists. | [Guide 02 §4.1](guides/02-cpu-core-isolation.md#41-systemd-cpuaffinity-persistent) |

### P

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="p-state"></a>**P-state** | **Performance state.** A pair of clock frequency and voltage that a running CPU uses. A lower P-state saves power and runs slower. | The guides keep every CPU at one fixed P-state, so handler times do not change. [Concept: power and frequency §3](concepts/power-and-frequency.md#3-frequency-p-states-and-who-chooses-them) |
| <a id="page-cache"></a>**page cache** | The memory where Linux keeps file data after reading or before writing it, so the next access does not need the disk. It grows into free memory. | It is why free memory always runs out on a busy host, and why reclaim matters. [Concept: memory reclaim §2](concepts/memory-reclaim.md#2-where-the-memory-goes) |
| <a id="page-fault"></a>**page fault (minor, major)** | The CPU stops a thread because the page it touched is not mapped. A **minor** fault only needs a fresh or cached page (about 1 µs). A **major** fault reads the page from disk (0.1 ms or more). | Faults on the hot path are latency spikes. Pre-touching and `mlockall` move or remove them. [Concept: memory reclaim §7](concepts/memory-reclaim.md#7-faults-what-a-missing-page-costs) |
| <a id="pam"></a>**PAM** | **Pluggable Authentication Modules.** The Linux login system. It also applies the limits of `limits.d` at login. | Limits set for login sessions do not apply to systemd services. [Guide 07 §3](guides/07-os-hygiene.md#3-resource-limits) |
| <a id="pause-frame"></a>**PAUSE frame** | A message from a network device that says "stop sending for a while". It is part of Ethernet flow control (IEEE 802.3x). | It can stop a whole port for milliseconds. It is turned off. [Guide 04 §5.4](guides/04-network-optimization.md#54-pause-frames-off-ethtool--a-autoneg-off-rx-off-tx-off) |
| <a id="pcie"></a>**PCIe** | **PCI Express.** The bus that connects a NIC and other cards to the CPU. | The NIC hangs off one socket, and that decides its [NUMA](#numa) node. [Guide 00 §4.7](guides/00-bios-firmware.md#47-pcie-and-devices) |
| <a id="percentile"></a>**percentile (p50, p99, p99.9)** | The value that a share of samples stays below. p99 means 99 of 100 samples are faster. p99.9 is the slow 1 in 1000. | Tuning shows in the high percentiles, not in the average. [Guide 09 §3.1](guides/09-measuring-latency.md#31-percentiles-not-averages) |
| <a id="pfc"></a>**PFC** | **Priority Flow Control.** Like a [PAUSE frame](#pause-frame), but for one traffic class instead of the whole port. | [Concept: ethtool §8](concepts/ethtool.md#8--a---a-flow-control-pause-frames) |
| <a id="phc"></a>**PHC** | **PTP Hardware Clock.** A clock inside the NIC. | It gives accurate time stamps. [Guide 10 §4](guides/10-time-sync.md#4-hardware-timestamping) |
| <a id="pid"></a>**PID** | **Process ID.** The number of a process. PID 1 is systemd, the first process. | [Guide 02 §4.1](guides/02-cpu-core-isolation.md#41-systemd-cpuaffinity-persistent) |
| <a id="pin"></a>**pin / pinning** | Fix a thread to one CPU, so that the scheduler never moves it. | Moving a thread loses its cache. [Guide 02 §6](guides/02-cpu-core-isolation.md#6-pinning-the-application) |
| <a id="pm-qos"></a>**PM QoS** | **Power Management Quality of Service.** A kernel interface (`/dev/cpu_dma_latency`). A program says how fast a CPU must wake, and the kernel limits sleep depth. | The `tuned` profile holds it open to keep CPUs out of deep [C-states](#cstate). [Guide 07 §5](guides/07-os-hygiene.md#5-tuned-profile) |
| <a id="pmd"></a>**PMD** | **Poll Mode Driver.** A [DPDK](#dpdk) driver that reads the NIC in a loop, with no interrupts. | A PMD thread uses 100% of one CPU. [Guide 08 §6.1](guides/08-kernel-bypass.md#61-how-it-works) |
| <a id="pre-touch"></a>**pre-touch** | Write to every page of a memory area when the program starts, so that no page fault happens later. | A page fault on the hot path costs microseconds. [Guide 03](guides/03-huge-pages-configuration.md) |
| <a id="printk"></a>**printk** | The function the Linux kernel uses to write a message to its log. A message more urgent than the console log level (the first number of `kernel.printk`) is also written to every console, and that write is done at once by the CPU that prints. | A slow console turns one message into a stall of milliseconds, so latency hosts set the console level to 1. [Guide 06 §2](guides/06-kernel-sysctl-tuning.md#2-kernel-logging-and-debug), [use case 16](examples/use-cases/16-the-log-line-that-cost-five-milliseconds.md) |
| <a id="psi"></a>**PSI** | **Pressure Stall Information.** Kernel numbers that show how long tasks waited for CPU, memory or disk. | An early sign that a group is short of a resource. [Concept: cgroups](concepts/cgroups.md#psi-pressure-stall-information) |
| <a id="ptp"></a>**PTP** | **Precision Time Protocol.** Clock synchronization to within microseconds or better, using network hardware. | [Guide 10 §7](guides/10-time-sync.md#7-ptp-with-linuxptp) |
| <a id="ptp-kvm"></a>**ptp_kvm** | A kernel module for [KVM](#kvm) guests. It shows the host clock to the guest as a [PTP](#ptp) clock device, `/dev/ptp0`. | `tools/check-vm` points chrony at it, so the guest clock synchronizes with no network time server. [CONTRIBUTING](CONTRIBUTING.md#workflow) |

### Q

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="qcow2"></a>**qcow2** | **QEMU Copy-On-Write, version 2.** The disk image format of [QEMU](#qemu). A qcow2 file can sit on top of another one and store only what changed. | Cloud images ship as qcow2. `tools/check-vm` starts every run from a thin layer on the cached image. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="qdisc"></a>**qdisc** | **Queueing discipline.** The kernel queue in front of the NIC transmit ring. | `txqueuelen` is its length. [Guide 04 §5.8](guides/04-network-optimization.md#58-txqueuelen-bulk-nics) |
| <a id="qemu"></a>**QEMU** | A program that runs a whole virtual machine. With [KVM](#kvm) it uses the CPU features of the host and is fast. | `tools/check-vm` boots RHEL-family cloud images in QEMU with two NUMA nodes and runs the guides in them. [CONTRIBUTING](CONTRIBUTING.md#workflow) |

### R

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="rcu"></a>**RCU** | **Read-Copy-Update.** A way for the kernel to update shared data without locks. Old copies are freed later by callbacks. | Those callbacks can run on your CPU, unless `rcu_nocbs` moves them. [Concept: bootloader §4](concepts/bootloader.md#4-how-the-main-parameters-work) |
| <a id="rdma"></a>**RDMA / RoCE** | **Remote Direct Memory Access,** and **RDMA over Converged Ethernet.** One machine writes into the memory of another one through the NICs, with no CPU work on the receiver. | A related low-latency family. It is not covered in depth here. [Guide 08 §2](guides/08-kernel-bypass.md#2-the-families-and-which-one-fits-your-card-and-application) |
| <a id="retpoline"></a>**retpoline** | **Return trampoline.** A compiler trick that replaces indirect jumps in the kernel with a sequence the CPU cannot be tricked into guessing. | A Spectre v2 defense. It makes every indirect call in the kernel a little slower. [Concept: security mitigations §3](concepts/security-mitigations.md#3-the-families-and-what-the-kernel-does) |
| <a id="rfs"></a>**RFS** | **Receive Flow Steering.** RPS that sends a flow to the CPU where its application runs. | Off for critical NICs. [Guide 04 §6.3](guides/04-network-optimization.md#63-rps-rfs-and-xps) |
| <a id="rhel"></a>**RHEL** | **Red Hat Enterprise Linux.** The Linux distribution that these guides target (versions 8, 9 and 10). | Every guide. |
| <a id="ring-buffer"></a>**ring buffer** | A fixed-size queue in a circle. One side writes at the head, the other reads at the tail, and both wrap around to the start. NICs use them to pass packets to the driver. | When the writer catches the reader, new items are lost. `ethtool -g` shows the size. [Concept: ethtool §5](concepts/ethtool.md#5--g---g-ring-sizes) |
| <a id="rocky-linux"></a>**Rocky Linux** | A free rebuild of RHEL made from the same source code. Its packages match RHEL and it needs no subscription. | CI runs the scripts in Rocky Linux 8 and 9 images, where every package of the guides can be installed. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="rps"></a>**RPS** | **Receive Packet Steering.** The software version of [RSS](#rss). The kernel picks a CPU for each packet, and it sends an [IPI](#ipi) to it. | It adds a hop, so it is off for critical NICs. [Guide 04 §6.3](guides/04-network-optimization.md#63-rps-rfs-and-xps) |
| <a id="rss"></a>**RSS** | **Receive-Side Scaling.** The NIC computes a hash of the packet headers and uses it to pick a receive queue. | Packets of one flow always land in the same queue. [Guide 04 §5.1](guides/04-network-optimization.md#51-queues-channels-ethtool--l) |
| <a id="rt"></a>**RT (real-time)** | A scheduling class where a thread runs before all normal threads, until it sleeps. | It can starve the operating system, so the kernel limits it. [Guide 02 §4.4](guides/02-cpu-core-isolation.md#44-real-time-throttling) |
| <a id="rt-throttling"></a>**RT throttling** | A kernel limit (`sched_rt_runtime_us`). It takes the CPU away from [real-time](#rt) tasks for a part of every second. | It stops a spinning real-time thread for 50 ms every second unless it is turned off. [Guide 02 §4.4](guides/02-cpu-core-isolation.md#44-real-time-throttling) |
| <a id="rto"></a>**RTO** | **Retransmission Timeout.** How long TCP waits for an [ACK](#ack) before it sends the data again. On Linux it is at least 200 ms. | One dropped segment costs at least one RTO. [Guide 04 §1](guides/04-network-optimization.md#1-where-network-latency-hides) |
| <a id="rtt"></a>**round-trip time (RTT)** | The time for a request to go to the peer and the answer to come back. | TCP builds its retransmission timer from it, and Linux never lets that timer go below 200 ms. [Concept: network tuning](concepts/network-tuning.md) |
| <a id="rx-missed-errors"></a>**rx_missed_errors** | A NIC counter in `ethtool -S`: the NIC had no free [descriptor](#descriptor) or no room in its [FIFO](#fifo) and dropped the frame. The exact name differs by driver. | The first counter to read when packets are missing. [Concept: network buffers §6](concepts/network-buffers.md#6-where-did-the-packet-die) |
| <a id="rx-nombuf"></a>**rx_nombuf** | A [DPDK](#dpdk) counter: the driver wanted an [mbuf](#mbuf) and the [mempool](#mempool) was empty. | The pool is too small, or the application holds buffers too long. [Concept: network buffers §7.1](concepts/network-buffers.md#71-dpdk) |
| <a id="rx-tx"></a>**RX / TX** | Receive and transmit. | Used in every network setting. [Guide 04](guides/04-network-optimization.md) |

### S

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="safepoint"></a>**safepoint / TTSP** | A point where the JVM can stop a thread and knows all its object references. Some JVM operations stop every Java thread at one. **TTSP** (time to safepoint) is how long the slowest thread takes to get there. | Every Java thread, pinned or not, waits for the slowest one. [Concept: JVM pauses §2](concepts/jvm-pauses.md#2-safepoints) |
| <a id="serial-console"></a>**serial console** | A text console on a serial port. In a [VM](#vm), QEMU writes the guest serial port to a file. | Kernel boot messages land there. `tools/check-vm` keeps it as a log of every boot. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="skmem"></a>**skmem** | The memory line that `ss -m` prints for a socket: `r` bytes queued for the reader, `rb` the limit, `t` and `tb` the same for sending, `d` the datagrams this socket dropped. | The quickest way to see a full receive buffer. [Concept: network buffers §4](concepts/network-buffers.md#4-socket-buffers) |
| <a id="slew"></a>**slew / step** | Two ways to correct a clock. A **slew** runs the clock a little faster or slower until the error is gone. A **step** sets the new time at once. | A step can make a duration negative. Time daemons should step only at boot. [Concept: clocks and time §5](concepts/clocks-and-time.md#5-step-and-slew) |
| <a id="slice"></a>**slice** | A systemd unit that is a node in the [cgroup](#cgroup) tree. Services are placed in slices. | [Guide 05 §4](guides/05-cgroup-isolation.md#4-design-three-slices) |
| <a id="smi"></a>**SMI** | **System Management Interrupt.** *S-M-I.* The firmware ([BIOS](#bios)) stops every CPU for a short time to do its own work, for example to check power or to emulate a USB keyboard. The operating system cannot see it and cannot stop it. | It shows up as a latency spike of tens to hundreds of µs (rarely milliseconds), and no log explains it. Count it with `turbostat`. [Guide 00 §4.6](guides/00-bios-firmware.md#46-system-management-interrupts) |
| <a id="smm"></a>**SMM** | **System Management Mode.** The CPU mode in which firmware code runs after an [SMI](#smi). The operating system is stopped and cannot see what happens. | Time in SMM is a freeze of every CPU. [Concept: power and frequency §6](concepts/power-and-frequency.md#6-smis-the-firmware-takes-every-cpu) |
| <a id="smt"></a>**SMT / Hyper-Threading** | **Simultaneous Multithreading.** One physical core shows up as two CPUs. Both share the caches and the execution units. | The sibling can slow the critical thread, so it is off or left idle. [Guide 00 §4.4](guides/00-bios-firmware.md#44-hyper-threading) |
| <a id="snc"></a>**SNC / NPS** | **Sub-NUMA Clustering** (Intel) and **NUMA Per Socket** (AMD). A socket presents itself as several [NUMA](#numa) nodes. | It changes the node layout that your configuration describes. [Guide 00 §4.5](guides/00-bios-firmware.md#45-memory-and-numa) |
| <a id="so-rcvbuf"></a>**SO_RCVBUF** | A socket option that sets the size of the receive buffer of one socket. The kernel doubles the value you give, and it caps it at `net.core.rmem_max`. | Too small, and datagrams are dropped during a burst. [Guide 06 §4](guides/06-kernel-sysctl-tuning.md#4-socket-buffers) |
| <a id="softirq"></a>**softirq** | **Software interrupt.** Work that the kernel postpones after a hard interrupt and runs soon on the same CPU. Network receive is the main example. | The protocol work of a packet runs here, not in your thread. [Concept: network tuning §4](concepts/network-tuning.md#4-napi-softirq-budget-and-ksoftirqd) |
| <a id="speculative-execution"></a>**speculative execution** | The CPU runs instructions before it knows they are needed, and discards the results if its guess was wrong. Traces stay in caches and buffers. | The root of Spectre, Meltdown and their relatives, and so of every [mitigation](#mitigation). [Concept: security mitigations §2](concepts/security-mitigations.md#2-the-idea-in-one-paragraph) |
| <a id="spsc"></a>**SPSC** | **Single Producer, Single Consumer.** A queue with exactly one writer thread and one reader thread. It needs no locks. | The usual way to pass data between pinned threads. [Concept: CPU isolation](concepts/cpu-isolation.md) |
| <a id="sr-iov"></a>**SR-IOV / VF** | **Single Root I/O Virtualization** and **Virtual Function.** A NIC presents itself as several small NICs, and each VF can go to a virtual machine. | The way to run [kernel bypass](#kernel-bypass) or [PTP](#ptp) in a VM. [Guide 08 §12](guides/08-kernel-bypass.md#12-bare-metal-vs-vm) |
| <a id="ssh"></a>**SSH** | **Secure Shell.** Remote login to a server. | If you change the NIC that your SSH session uses, the session drops. [Guide 04](guides/04-network-optimization.md) |
| <a id="swap"></a>**swap** | Disk space where the kernel writes anonymous memory (heap, stacks) to free RAM. Reading it back is a major [page fault](#page-fault). | A swapped page costs milliseconds on the thread that touches it, and nothing is logged. [Concept: swap and the OOM killer §2](concepts/swap-and-oom.md#2-what-swap-does) |
| <a id="swappiness"></a>**swappiness** | `vm.swappiness`, 0–200: how much the kernel prefers dropping page cache over swapping. It is a preference, not a switch. | `0` does not turn swap off. [Concept: swap and the OOM killer §3](concepts/swap-and-oom.md#3-what-vmswappiness-really-means) |
| <a id="syn"></a>**SYN** | The first packet of a TCP connection ("synchronize"). | A queue of half-open connections waits on it. [Guide 06 §3](guides/06-kernel-sysctl-tuning.md#3-tcp-behavior) |
| <a id="systemd-analyze"></a>**systemd-analyze** | A systemd command. `systemd-analyze verify FILE` reads a unit file and reports typos, unknown settings and missing programs without starting anything. | `tools/check-containers` runs it on every unit file that the scripts write, on each RHEL-family image. [CONTRIBUTING](CONTRIBUTING.md#workflow) |

### T

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="tai"></a>**TAI** | **International Atomic Time.** A time scale with no [leap seconds](#leap-second). It is ahead of UTC by a fixed number of seconds. | PTP runs on TAI, and `CLOCK_TAI` gives it in Linux. [Concept: clocks and time §4](concepts/clocks-and-time.md#4-which-clock-to-read) |
| <a id="tail-latency"></a>**tail latency** | The slow end of the latency distribution: p99 and above. | Users notice the tail, and interruptions cause it. [Guide 09](guides/09-measuring-latency.md) |
| <a id="tap-device"></a>**tap device** | A virtual network card on the host. What the host writes to it, a program such as [QEMU](#qemu) reads as frames from the wire, and the other way around. With `multi_queue` it has several queues. | `tools/check-vm` backs the critical NIC of the guest with one, so the guest sees a [virtio](#virtio) NIC with 4 queues. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="tcp"></a>**TCP** | **Transmission Control Protocol.** A reliable, ordered byte stream. A lost packet is sent again after a timeout ([RTO](#rto)). | [Guide 06 §3](guides/06-kernel-sysctl-tuning.md#3-tcp-behavior) |
| <a id="tcp-nodelay"></a>**TCP_NODELAY** | A socket option that turns [Nagle's algorithm](#nagle) off. | Set it on every latency-critical TCP socket. [Concept: network tuning §6](concepts/network-tuning.md#6-transmit-path) |
| <a id="thp"></a>**THP** | **Transparent Huge Pages.** The kernel creates and merges huge pages by itself, at times you do not choose. | It can stall a thread while it works, so it is off. [Guide 03 §2](guides/03-huge-pages-configuration.md#2-transparent-vs-explicit-huge-pages-why-thp-is-off) |
| <a id="tick"></a>**tick** | The timer interrupt that fires on each CPU, 1000 times per second on RHEL for x86_64 (`CONFIG_HZ=1000`). | Each one interrupts the running thread for 1–5 µs. [Concept: bootloader §4](concepts/bootloader.md#4-how-the-main-parameters-work) |
| <a id="tlb"></a>**TLB / DTLB / STLB** | **Translation Lookaside Buffer.** A small cache in the CPU (in levels: DTLB for data, STLB shared). It remembers how virtual addresses map to physical memory. | A miss costs tens to hundreds of ns. [Concept: huge pages §2](concepts/huge-pages.md#2-translation-page-tables-and-the-tlb) |
| <a id="tlb-reach"></a>**TLB reach** | The amount of memory that the [TLB](#tlb) covers: the number of entries times the page size. | Bigger pages give a bigger reach. [Concept: huge pages §2](concepts/huge-pages.md#2-translation-page-tables-and-the-tlb) |
| <a id="tlb-shootdown"></a>**TLB shootdown** | When a process changes its memory map, the kernel sends an [IPI](#ipi) to every CPU running a thread of that process, so each one drops the old [TLB](#tlb) entries. | It reaches isolated CPUs too, and the `TLB` row of `/proc/interrupts` counts it. [Concept: interrupts and deferred work §4](concepts/interrupts-and-deferred-work.md#4-ipis-interrupts-from-other-cpus) |
| <a id="truesize"></a>**truesize** | The real memory that the kernel charges to a socket for one received packet: the data, the headers and the buffer around them. It is much larger than the payload for small packets. | A small receive buffer holds fewer packets than you expect. `ss -m` shows the numbers. [Guide 06 §4](guides/06-kernel-sysctl-tuning.md#4-socket-buffers) |
| <a id="tsc"></a>**TSC** | **Time Stamp Counter.** A counter in the CPU that counts cycles. It is the fastest clock source in Linux. | `clock_gettime()` reads it in tens of ns, with no system call. [Guide 10 §2](guides/10-time-sync.md#2-clocks-in-linux-briefly) |
| <a id="tso"></a>**TSO** | **TCP Segmentation Offload.** The NIC cuts one large TCP send into normal-size packets. | Good for throughput, and it batches. [Guide 04 §5.5](guides/04-network-optimization.md#55-segmentation-and-aggregation-offloads-off-ethtool--k-tso-off-gso-off-lro-off) |
| <a id="tsx"></a>**TSX** | **Transactional Synchronization Extensions.** An Intel CPU feature for hardware transactions. One of its side channels has a mitigation (TAA). | The mitigation costs speed, and it can be switched off. [Guide 01 §5](guides/01-grub-bootloader-tuning.md#5-the-parameters-one-by-one) |
| <a id="tuned"></a>**tuned** | A Red Hat service that applies named sets of system settings (profiles). | The `network-latency` profile. [Guide 07 §5](guides/07-os-hygiene.md#5-tuned-profile) |
| <a id="turbo"></a>**turbo** | A CPU feature (Intel Turbo Boost, AMD Core Performance Boost) that runs the cores above their base clock while the chip stays under its power and temperature limits. Fewer busy cores and a cooler chip mean a higher clock. | The clock then changes with heat and load, so the latency does too. Latency hosts decide it by measuring. [Guide 00 §4.3](guides/00-bios-firmware.md#43-turbo-a-measured-decision), [use case 13](examples/use-cases/13-turbo-the-lottery.md) |
| <a id="turbostat"></a>**turbostat** | A Linux tool (package `kernel-tools`) that reads CPU counters: the real clock of each CPU (`Bzy_MHz`), temperatures, and the count of [SMIs](#smi). | The only OS tool that counts SMIs, and the way to see the clock move with temperature. [Guide 00 §7](guides/00-bios-firmware.md#7-verification) |

### U

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="ubi"></a>**UBI** | **Universal Base Image.** A container image of RHEL user space (bash, coreutils, dnf) that Red Hat lets anyone download and share, with no subscription. | CI runs `tools/check-scripts` and `tools/check-containers` in UBI 8, 9 and 10, so the scripts meet the real RHEL shell, systemd and package manager. It never boots a RHEL kernel. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="udp"></a>**UDP** | **User Datagram Protocol.** Sends single packets with no connection and no resending. | A lost datagram is gone, so the receive buffer must hold a whole [burst](#burst). [Guide 06 §4](guides/06-kernel-sysctl-tuning.md#4-socket-buffers) |
| <a id="umem"></a>**UMEM** | **User Memory.** In [AF_XDP](#af-xdp), the block of memory that the program registers, from which the packet buffers are taken. | [Guide 08 §7](guides/08-kernel-bypass.md#7-other-stacks-briefly) |
| <a id="uncore"></a>**uncore** | The parts of a CPU socket that are not cores: the L3 cache, the on-chip connections, the memory controllers. It has its own clock. | A slow uncore makes every L3 hit and memory access slower. [Guide 00 §4.1](guides/00-bios-firmware.md#41-power-and-performance-profile) |
| <a id="upi"></a>**UPI** | **Ultra Path Interconnect.** Intel's link between the sockets of a server. | Every access to memory or a cache on the other socket crosses it, which adds about 60–100 ns. [Concept: hardware topology §2.3](concepts/hardware-topology.md#23-numa-nodes-and-the-socket-link) |
| <a id="usb-emulation"></a>**USB emulation** | The firmware makes a USB keyboard look like an old PS/2 device, and it uses [SMIs](#smi) to do it. | Turn it off on servers without a local keyboard. [Guide 00 §4.6](guides/00-bios-firmware.md#46-system-management-interrupts) |
| <a id="user-mode-networking"></a>**user-mode networking** | The network of [QEMU](#qemu) that needs no host setup (also called SLIRP). QEMU itself plays the router, and can forward a host port into the guest. It has one queue only. | `tools/check-vm` gives the mgmt NIC this network: SSH through a forwarded port, and the internet for `dnf`. [CONTRIBUTING](CONTRIBUTING.md#workflow) |
| <a id="utc"></a>**UTC** | **Coordinated Universal Time.** The world's reference wall-clock time. | `CLOCK_REALTIME` follows it, including its [leap seconds](#leap-second). [Concept: clocks and time §4](concepts/clocks-and-time.md#4-which-clock-to-read) |
| <a id="utilization"></a>**utilization** | The share of time a server (a thread, a CPU, a link) is busy with work: arrival rate × service time. | Waiting grows like 1/(1 − utilization), so a thread at 90 % has a p99 of about 46 service times. [Concept: queueing §3](concepts/queueing.md#3-why-waiting-explodes-near-full-load) |

### V

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="vdso"></a>**vDSO** | **virtual Dynamic Shared Object.** A small piece of kernel code mapped into every process, so some calls such as `clock_gettime()` run without entering the kernel. | It makes a clock read cost tens of ns, but only with the `tsc` [clocksource](#clocksource). [Concept: clocks and time §3](concepts/clocks-and-time.md#3-the-tsc-and-the-clocksource) |
| <a id="vfio"></a>**VFIO** | **Virtual Function I/O.** A Linux framework that gives a user-space program safe access to a PCI device, through the [IOMMU](#iommu). | [DPDK](#dpdk) uses it. [Guide 08 §6.2](guides/08-kernel-bypass.md#62-binding-ports) |
| <a id="vga"></a>**VGA console** | The screen output of kernel messages. Writing to it (or to a slow serial console) is synchronous, so it can block a CPU for milliseconds. | The guides limit console messages. [Guide 01 §5](guides/01-grub-bootloader-tuning.md#5-the-parameters-one-by-one) |
| <a id="vi"></a>**VI** | **Virtual Interface.** On Solarflare NICs, one set of hardware queues (receive, transmit and events) that one program owns. | [Onload](#onload) creates VIs for its stacks. [Guide 08 §5.1](guides/08-kernel-bypass.md#51-how-onload-works) |
| <a id="virtio"></a>**virtio** | The standard family of virtual devices in a [KVM](#kvm) guest: disk, network and more. `virtio-net` is the network card, and it can have several queue pairs. | The guides tune it like a physical NIC, with fewer settings. [Guide 04](guides/04-network-optimization.md) |
| <a id="vlan"></a>**VLAN** | **Virtual LAN.** A tag in the packet that splits one physical network into several logical ones. | The NIC can filter by VLAN. [Concept: network tuning §2](concepts/network-tuning.md#2-the-receive-path-step-by-step) |
| <a id="vm"></a>**VM** | **Virtual machine.** | Many tunings are only partly possible in a VM. [Guide 00 §10](guides/00-bios-firmware.md#10-bare-metal-vs-vm) |

### W

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="watermark"></a>**watermark** | One of three free-memory levels per memory zone (min, low, high), in `/proc/zoneinfo`. Below low, [kswapd](#kswapd) wakes. Below min, allocations do [direct reclaim](#direct-reclaim). `vm.min_free_kbytes` sets min, and the other two follow. | Higher watermarks give background reclaim time to work before a thread has to stop. [Guide 06 §8](guides/06-kernel-sysctl-tuning.md#8-virtual-memory) |
| <a id="workqueue"></a>**workqueue** | A kernel mechanism that runs postponed work in [kworker](#kworker) threads. An "unbound" workqueue may use any CPU that you allow. | Unbound workqueues are restricted to the [housekeeping CPUs](#housekeeping-cpu). [Guide 02 §4.2](guides/02-cpu-core-isolation.md#42-unbound-kernel-workqueues-runtime) |

### X

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="xdp"></a>**XDP** | **eXpress Data Path.** A hook in the NIC driver where a small [BPF](#bpf) program handles each packet before the normal stack. | The base of [AF_XDP](#af-xdp). [Guide 08 §7](guides/08-kernel-bypass.md#7-other-stacks-briefly) |
| <a id="xlio"></a>**XLIO / VMA** | NVIDIA's user-space socket library for ConnectX NICs (the successor of VMA). It works like [Onload](#onload). | [Guide 08 §7](guides/08-kernel-bypass.md#7-other-stacks-briefly) |
| <a id="xps"></a>**XPS** | **Transmit Packet Steering.** It chooses the transmit queue by the CPU that sends. | [Guide 04 §6.3](guides/04-network-optimization.md#63-rps-rfs-and-xps) |

### Z

| Term | Means | Why you meet it here |
|---|---|---|
| <a id="zgc"></a>**ZGC** | A [JVM](#jvm) garbage collector that keeps pauses very short. | It fails at start when huge pages are missing. [Guide 03 §5](guides/03-huge-pages-configuration.md#5-java-applications) |
| <a id="zram"></a>**zram** | A compressed disk in RAM, often used as a [swap](#swap) device (`/dev/zram0`). | It makes swap faster, but a swap-in is still a fault on the hot path. [Concept: swap and the OOM killer §4](concepts/swap-and-oom.md#4-compressed-swap-zswap-and-zram) |
| <a id="zswap"></a>**zswap** | A compressed cache in RAM in front of a [swap](#swap) device. Pages are compressed there before they go to disk. | Off by default on RHEL. Check `/sys/module/zswap/parameters/enabled`. [Concept: swap and the OOM killer §4](concepts/swap-and-oom.md#4-compressed-swap-zswap-and-zram) |

## Everyday words with a special meaning here

These words are normal English, and they are used in a special way in these guides. A dictionary will not warn you.

| Word | In these guides it means |
|---|---|
| **bypass** | To go around something. "Kernel bypass" goes around the kernel network stack. |
| **canary host** | One host that gets a change first. If it goes wrong, only that host is affected, and the rest of the fleet waits. |
| **drain** | To take items out of a queue. A queue drains when the reader is faster than the writer. |
| **drop** | A packet that is thrown away because there was no room for it. |
| **hot path** | The code that runs for every message, where a delay is paid every time. |
| **isolate** | To keep a CPU for one job only. Nothing else may run there. |
| **noisy neighbor** | Another program on the same server that uses shared resources and disturbs yours. |
| **park** | To send a thread or a CPU to a place where it does no harm, or to sleep. |
| **spin** | To run a loop that only waits, without sleeping, so that the reaction is immediate. It keeps the CPU 100% busy. |
| **stall** | A short stop in which a thread makes no progress. |
| **starve** | A thread cannot run, because others use all of the resource. |
| **tail** | The slowest few results. "The tail" is the slow end of a histogram. |
| **warm / cold cache** | Warm: the data is already in the CPU cache. Cold: it is not, and the first access is slow. |

## Units and quick numbers

| Unit | Means | To get a feeling |
|---|---|---|
| **ns** | nanosecond, 10⁻⁹ s | Light travels about 30 cm. A cache hit takes a few ns, and a memory access about 100 ns. |
| **µs** | microsecond, 10⁻⁶ s (1000 ns) | An interrupt and its softirq cost 1–50 µs. A kernel-stack packet takes about 5–10 µs to reach the program. |
| **ms** | millisecond, 10⁻³ s (1000 µs) | A [PAUSE frame](#pause-frame) can stop a port for this long. |
| **KiB, MiB, GiB** | 1024, 1024², 1024³ bytes | Memory sizes. KB, MB and GB (powers of 10) are a little smaller. |
| **Mpps** | million packets per second | 10 GbE with 64-byte packets is about 14.88 Mpps. With 1500-byte packets it is about 0.81 Mpps. |
| **Gb/s, GbE** | gigabits per second, Gigabit Ethernet | 10 Gb/s is 1.25 GB/s. |

The typical cost of each event, in one table, is in the [cheat sheet](CHEATSHEET.md#orders-of-magnitude).
| **GHz** | gigahertz, 10⁹ clock cycles per second | A 3 GHz core runs 3 cycles per ns. A clock that drops from 3.3 to 3.0 GHz makes every handler about 10 % slower. |
| **ppm** | parts per million, 10⁻⁶ | A clock that is 500 ppm fast gains 0.5 ms every second. That is the kernel's largest [slew](#slew). |

## Key takeaways

- **Look the term up before you guess.** A wrong guess about SMI, NAPI or a ring buffer leads to a wrong fix.
- **Every entry says why it matters.** If you cannot see why a term matters for your host, you can skip it.
- **Some ordinary words have a special meaning** (spin, pin, drop, tail). Read the table of everyday words once.
- **Tell us what is missing.** A term that a reader had to search for elsewhere is a bug in this page.
