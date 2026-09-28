# Example — Java on a Tuned Host: Pinned Threads, Huge Pages, NUMA, ZGC

> Code: [`examples/java-latency-probe/`](java-latency-probe/) · Guides: [02 CPU isolation](../guides/02-cpu-core-isolation.md), [03 Huge pages](../guides/03-huge-pages-configuration.md) · Concept: [huge-pages](../concepts/huge-pages.md)

This example is a small, complete Java program. It shows how a latency-critical JVM application is **launched and wired** on a host tuned with Guides 01–07, and it gives you a probe to measure what the tuning bought you.

- Thread roles are mapped to isolated CPUs in a properties file. Each thread pins **itself** before touching its data.
- A launcher picks the JVM options file by host class, and adds `-XX:+UseNUMA -XX:+UseLargePages -XX:+AlwaysPreTouch` **only when affinity is enabled**.
- Two histograms are recorded: core-to-core round trip, and dependent random memory reads (TLB/cache).

## 1. Layout

```
java-latency-probe/
├── build.gradle.kts                          Java 25 toolchain, HdrHistogram, dependency allowlist
├── settings.gradle.kts                       repositories (project-level repositories fail the build)
├── gradlew, gradle/                          wrapper (checksum-pinned), verification-metadata.xml
├── .sdkmanrc                                 java / gradle versions for `sdk env`
├── bin/launch                                host-aware launcher
├── conf/
│   ├── application.properties                affinity switch, thread->CPU map, probe parameters
│   ├── jvm.options                           bare metal: -Xms=-Xmx, ZGC, -ZUncommit
│   └── jvm-low-resource.options              VMs/dev: small elastic heap
└── src/main/java/com/example/lowlat/
    ├── LatencyProbe.java                     ping-pong + random walk, histograms
    ├── AffinityConfig.java                   role -> CPU lookup
    ├── ThreadAffinity.java                   sched_setaffinity / sched_getcpu through FFM
    ├── PaddedSequence.java                   single-writer sequence on its own cache line
    └── IdleStrategy.java                     spin vs backoff
```

## 2. Prerequisites on the host

| Requirement | Check |
|---|---|
| JDK 25 (FFM API, final since 22). With SDKMAN: `sdk env install` in the project reads `.sdkmanrc` | `java -version`, `./gradlew -v` |
| Guides 01–03 applied (bare metal) | `scripts/verify-tuning.sh` |
| CPUs 9 and 11 isolated and on the NIC's node (edit `application.properties` for your layout) | `cat /sys/devices/system/cpu/isolated` |
| Enough huge pages **on that node** for heap + code cache: 4 GiB heap + 240 MiB code cache ≈ **2,200 × 2 MiB** | `cat /sys/devices/system/node/node1/hugepages/hugepages-2048kB/free_hugepages` |
| `numactl` installed (optional, for `APP_NUMA_NODE`) | `numactl -H` |
| Run as a normal user with `memlock`/`rtprio` limits ([Guide 07 §3](../guides/07-os-hygiene.md#3-resource-limits)) | `ulimit -l -r` |

## 3. Build and run

```bash
cd examples/java-latency-probe
./gradlew build                       # build/classes/java/main + build/lib/*.jar

# Bare metal, tuned: pinned, huge pages, heap bound to node 1
APP_NUMA_NODE=1 bin/launch

# Same host, untuned JVM for comparison: no pinning, no large pages
sed -i 's/^affinity.enable=true/affinity.enable=false/' conf/application.properties
bin/launch
```

## 4. What the launcher does

[`bin/launch`](java-latency-probe/bin/launch), the part that matters:

```bash
HOST_CLASS="$(host_class_detect)"                     # systemd-detect-virt: bare_metal / virtual_machine
if [[ "${HOST_CLASS}" == bare_metal ]]; then
	JVM_OPTIONS_FILE="${CONF_DIR}/jvm.options"
else
	JVM_OPTIONS_FILE="${CONF_DIR}/jvm-low-resource.options"
fi

PARAMS=("-XX:VMOptionsFile=${JVM_OPTIONS_FILE}" --enable-native-access=ALL-UNNAMED)

if [[ "$(property affinity.enable)" == true ]]; then
	PARAMS+=(-XX:+UseNUMA -XX:+UseLargePages -XX:+AlwaysPreTouch)
fi

[[ -n "${APP_NUMA_NODE:-}" ]] && PREFIX+=(numactl "--membind=${APP_NUMA_NODE}")
[[ -n "${BYPASS_LAUNCHER:-}" ]] && PREFIX+=(${BYPASS_LAUNCHER})     # e.g. "<bypass-cmd> -p latency"

exec "${PREFIX[@]}" java "${PARAMS[@]}" -cp "build/classes/java/main:build/lib/*" com.example.lowlat.LatencyProbe
```

Design decisions:

| Decision | Reason |
|---|---|
| Two options files, selected by host class | The same artifact runs everywhere. VMs get a heap that can shrink (`SoftMaxHeapSize`) and no large-page dependency. |
| Large-page flags tied to `affinity.enable` | Pinning, NUMA placement, and a reserved pool only make sense together. On a host without a pool, `UseLargePages` degrades (G1) or fails (ZGC). |
| `-Xms` = `-Xmx` in `jvm.options` | The whole heap is committed and, with pre-touch, faulted in before the first message |
| `-XX:-ZUncommit` | ZGC never gives memory back, so it never has to fault it in again mid-session |
| `numactl --membind` (optional) | All heap pages come from the critical node's pool. Size that node's pool for the full heap. |
| Refuses to run as root | Production processes should run under an application account with explicit `rtprio`/`memlock` limits |
| `--enable-native-access=ALL-UNNAMED` | Thread pinning calls `sched_setaffinity()` through the FFM API, a restricted operation |
| Optional bypass prefix | Kernel-bypass launchers wrap the JVM. The prefix is added only if the tool is installed. |

`conf/jvm.options`:

```text
-Xms4g
-Xmx4g
-XX:+UseZGC
-XX:-ZUncommit
-XX:+UnlockDiagnosticVMOptions
-XX:+PrintCommandLineFlags
-XX:-OmitStackTraceInFastThrow
-Xlog:gc*,gc+init:file=log/gc.log:time,tags
-Djava.net.preferIPv4Stack=true
-Djava.security.egd=file:/dev/urandom
```

On JDK 25, ZGC is always generational, which reduces allocation stalls for a heap of several GiB.

`conf/jvm-low-resource.options`:

```text
-Xmx2g
-XX:SoftMaxHeapSize=1g
-XX:+UseZGC
-XX:-ZUncommit
...
```

## 5. What the Java code does

Thread pinning happens **inside** the thread, before it allocates or touches its data. With `-XX:+UseNUMA`, first-touch then places that data on the thread's node:

```java
private static Thread pinnedThread(String name, int cpu, Runnable body) {
    return new Thread(() -> {
        if (cpu >= 0) {
            ThreadAffinity.pinCurrentThread(cpu);      // sched_setaffinity(0, ...) via FFM: this thread only
        }
        body.run();
    }, name);
}
```

The two threads exchange a sequence number through two `PaddedSequence` objects. Each has one writer and sits on its own cache line, so the round trip measures exactly one cache-line transfer in each direction:

```java
for (long i = 0; i < total; i++) {
    long t0 = System.nanoTime();
    ping.set(i);                                       // release store
    while (pong.get() != i) { idle.idle(0); }          // acquire load, PAUSE while waiting
    long t1 = System.nanoTime();
    for (int h = 0; h < hops; h++) {
        index = (int) table[index];                    // dependent random reads over 1 GiB
    }
    long t2 = System.nanoTime();
    rtt.recordValue(t1 - t0);
    walk.recordValue(t2 - t1);
}
```

`table` is a random single cycle (Sattolo's shuffle) over `probe.working.set.mib`. Every hop is a cache miss and, with 4 KiB pages, almost always a TLB miss. With 2 MiB pages, 1 GiB fits in the TLB reach of a modern core. The walk histogram is where huge pages show up, and the RTT histogram is where isolation and interrupt placement show up.

## 6. Reading the output

```
host_class=bare_metal jvm-options=jvm.options
config=/opt/lowlat/app/conf/application.properties affinity.enable=true idle.strategy=spin
  -XX:UseLargePages=true
  -XX:UseTransparentHugePages=false
  -XX:UseNUMA=true
  -XX:AlwaysPreTouch=true
  -XX:UseZGC=true
  -XX:MaxHeapSize=4294967296
  HugePages_Total:   14336
  HugePages_Free:    12108
  ...
thread ping  requested cpu=9   running on cpu=9 affinity={9}
thread pong  requested cpu=11  running on cpu=11 affinity={11}

rtt  (ping -> pong -> ping, ns)
  count=10000000  min=...  p50=...  p90=...  p99=...  p99.9=...  p99.99=...  max=...

walk (4 dependent random reads over 1024 MiB, ns)
  count=10000000  min=...  p50=...  p99=...  ...
```

What to check:

1. `UseLargePages=true` **and** `HugePages_Free` dropped by about 2,200 pages compared with before start-up (heap + code cache). If `Free` did not move, the heap is not on huge pages: check `log/gc.log` for the `Large Page Support` line and a *Failed to reserve* warning.
2. `running on cpu` equals the requested CPU, and `affinity` is a single CPU.
3. The shape, not the absolute numbers. Absolute values depend on the CPU generation and the distance between the two cores. On a tuned host, look for:
   - **rtt**: p99.99 within a small multiple of p50, and a `max` that is not orders of magnitude higher. Large max values point to interrupts, the tick, or SMIs on the isolated CPUs ([Guide 02 §8](../guides/02-cpu-core-isolation.md#8-verification)).
   - **walk**: a clearly lower p50 and tail with `-XX:+UseLargePages` than without. Run both variants, because that difference is the TLB effect.
4. Put `ping` and `pong` on the **other** NUMA node (or the same core's HT sibling, if HT is on) and watch the RTT change. That is the interconnect (or shared L1) made visible.

Record results before and after each guide. The combination of this probe and `rtla osnoise` on the same CPUs is a good acceptance test for a new host.

## 7. Integrating the pattern into a real application

- **One role per critical thread, one CPU per role**, in configuration. Log the requested vs actual CPU at start-up, as the probe does, and alert when they differ.
- Non-critical threads (GC workers, JIT compiler, logging, admin HTTP) are **not** pinned. They inherit the launch mask, the OS CPUs, from systemd `CPUAffinity`. If they share the critical node, keep one or two non-isolated CPUs there for them.
- Idle strategy per profile: `spin` on isolated CPUs, `backoff` elsewhere. The same switch that selects the options file can select the idle strategy.
- Other JVMs on the same host that run latency-critical loops use the same launcher logic: large-page flags when pinned, busy-spin idle strategies on bare metal, back-off on VMs.
- Off-heap buffers (`allocateDirect`, mapped files) are **not** covered by `-XX:+UseLargePages`. Map them from hugetlbfs when they are large and randomly accessed ([Guide 03 §6](../guides/03-huge-pages-configuration.md#6-c-and-c-applications) shows the native equivalent).

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to reserve large pages memory` / ZGC commit error at start | Pool too small **on the node the JVM allocates from** | `numastat -m`; grow `HUGEPAGES_PER_NODE`; with `APP_NUMA_NODE` the whole heap must fit in that node |
| `sched_setaffinity(cpu=N) failed: errno=22` at start | CPU outside the process's cpuset (cgroup), or offline | `cat /proc/self/status` → `Cpus_allowed_list`; [Guide 05 §4.4](../guides/05-cgroup-isolation.md#44-the-cpuset-trap) |
| `UnsupportedOperationException: thread affinity needs Linux` | `affinity.enable=true` on macOS/Windows | Set `affinity.enable=false` for local runs |
| JDK warning about a restricted method / native access | Started without the launcher | Add `--enable-native-access=ALL-UNNAMED` |
| `running on cpu` ≠ requested | CPU outside the process's cpuset, or offline | `cat /proc/self/status` → `Cpus_allowed_list`; [Guide 05 §4.4](../guides/05-cgroup-isolation.md#44-the-cpuset-trap) |
| Start-up takes a long time | `AlwaysPreTouch` over a large heap | Expected: seconds per 10 GiB. Pay it before the session. |
| `OutOfMemoryError: Java heap space` | Working set larger than the heap | Lower `probe.working.set.mib` or raise `-Xmx` (and the pool) |
| Great p50, terrible max | Noise on the isolated CPUs | `rtla osnoise top -c 9,11`; check `/proc/interrupts` on 9 and 11 |
| Numbers identical with/without large pages | Pages not actually huge (THP flag used, or pool empty), or the table fits in the TLB anyway | Check `smaps` `KernelPageSize`; raise `probe.working.set.mib` |

## 9. Customisation points

| Where | What |
|---|---|
| `conf/application.properties` | CPUs per role, idle strategy, iterations, working set, hops |
| `conf/jvm.options` | Heap size (keep ≤ the node's pool), collector, logging |
| `bin/launch` | Host classification, NUMA binding, bypass prefix, extra flags per environment |
| `IdleStrategy` | Spin/backoff thresholds |
| `build.gradle.kts` | Dependencies. Only `approvedDependencies` may resolve, and every artifact's checksum is pinned in `gradle/verification-metadata.xml` (regenerate with `./gradlew --write-verification-metadata sha256 build` after an approved change). |
