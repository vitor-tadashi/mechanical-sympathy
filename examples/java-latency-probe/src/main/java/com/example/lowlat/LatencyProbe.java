package com.example.lowlat;

import com.sun.management.HotSpotDiagnosticMXBean;
import org.HdrHistogram.Histogram;

import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.SplittableRandom;
import java.util.concurrent.TimeUnit;

/**
 * Latency probe for a tuned host.
 * <p>
 * Two pinned threads play ping-pong through two padded sequences (one cache line each):
 *   ping: writes i, spins until pong echoes i            -> "rtt" histogram (core-to-core)
 *   ping: then does N dependent random reads in a large table -> "walk" histogram (memory/TLB)
 * <p>
 * On a tuned bare-metal host with isolated CPUs, huge pages and pre-touch, both
 * distributions are tight; on an untuned host the tails show scheduler, interrupt and
 * TLB noise. Compare runs with and without the launcher's large page flags.
 */
public final class LatencyProbe {

    private static final long HIGHEST_TRACKABLE_NS = TimeUnit.SECONDS.toNanos(10);

    public static void main(final String[] args) throws Exception {
        final Path configFile = Path.of(System.getProperty("probe.config", "conf/application.properties"));
        final AffinityConfig config = AffinityConfig.load(configFile);

        final long iterations = Long.parseLong(config.get("probe.iterations", "10000000"));
        final long warmup = Long.parseLong(config.get("probe.warmup", "1000000"));
        final int workingSetMiB = Integer.parseInt(config.get("probe.working.set.mib", "1024"));
        final int hops = Integer.parseInt(config.get("probe.hops", "4"));
        final String idleName = config.get("idle.strategy", config.enabled() ? "spin" : "backoff");

        printEnvironment(config, configFile, idleName);

        final PaddedSequence ping = new PaddedSequence(-1);
        final PaddedSequence pong = new PaddedSequence(-1);
        final Histogram rtt = new Histogram(HIGHEST_TRACKABLE_NS, 3);
        final Histogram walk = new Histogram(HIGHEST_TRACKABLE_NS, 3);
        final long total = warmup + iterations;

        final Thread pongThread = pinnedThread("pong", config.cpuFor("pong"), () -> {
            final IdleStrategy idle = IdleStrategy.of(idleName);
            long last = -1;
            while (last < total - 1) {
                final long seq = ping.get();
                if (seq == last) {
                    idle.idle(0);
                    continue;
                }
                pong.set(seq);
                last = seq;
                idle.idle(1);
            }
        });

        final Thread pingThread = pinnedThread("ping", config.cpuFor("ping"), () -> {
            // Built by the pinned thread: with -XX:+UseNUMA the table lands on this thread's node.
            final long[] table = randomCycle(workingSetMiB * 1024L * 1024L / Long.BYTES);
            final IdleStrategy idle = IdleStrategy.of(idleName);
            int index = 0;
            for (long i = 0; i < total; i++) {
                final long t0 = System.nanoTime();
                ping.set(i);
                while (pong.get() != i) {
                    idle.idle(0);
                }
                final long t1 = System.nanoTime();
                for (int h = 0; h < hops; h++) {
                    index = (int) table[index]; // dependent load: no prefetching, one TLB lookup each
                }
                final long t2 = System.nanoTime();
                if (i >= warmup) {
                    rtt.recordValue(t1 - t0);
                    walk.recordValue(t2 - t1);
                }
            }
            if (index == Integer.MIN_VALUE) { // keeps the JIT from removing the walk
                System.out.println(index);
            }
        });

        pongThread.start();
        pingThread.start();
        pingThread.join();
        pongThread.join();

        report("rtt  (ping -> pong -> ping, ns)", rtt);
        report("walk (" + hops + " dependent random reads over " + workingSetMiB + " MiB, ns)", walk);
    }

    private static Thread pinnedThread(final String name, final int cpu, final Runnable body) {
        final Thread thread = new Thread(() -> {
            if (cpu >= 0) {
                ThreadAffinity.pinCurrentThread(cpu); // before touching any data: first-touch on the right node
            }
            System.out.printf("thread %-5s requested cpu=%-3s running on cpu=%d affinity=%s%n",
                    name, cpu >= 0 ? Integer.toString(cpu) : "-", ThreadAffinity.currentCpu(), ThreadAffinity.currentAffinity());
            body.run();
        }, name);
        thread.setDaemon(false);
        return thread;
    }

    /** Sattolo's algorithm: a random single cycle, so the walk visits the table without short loops. */
    private static long[] randomCycle(final long entries) {
        final int n = (int) Math.min(entries, Integer.MAX_VALUE - 8);
        final long[] table = new long[n];
        for (int i = 0; i < n; i++) {
            table[i] = i;
        }
        final SplittableRandom random = new SplittableRandom(42);
        for (int i = n - 1; i > 0; i--) {
            final int j = random.nextInt(i);
            final long tmp = table[i];
            table[i] = table[j];
            table[j] = tmp;
        }
        return table;
    }

    private static void report(final String title, final Histogram h) {
        System.out.printf("%n%s%n", title);
        System.out.printf("  count=%d  min=%d  p50=%d  p90=%d  p99=%d  p99.9=%d  p99.99=%d  max=%d%n",
                h.getTotalCount(), h.getMinValue(),
                h.getValueAtPercentile(50), h.getValueAtPercentile(90), h.getValueAtPercentile(99),
                h.getValueAtPercentile(99.9), h.getValueAtPercentile(99.99), h.getMaxValue());
    }

    private static void printEnvironment(final AffinityConfig config, final Path configFile, final String idleName) throws Exception {
        final HotSpotDiagnosticMXBean hotspot = ManagementFactory.getPlatformMXBean(HotSpotDiagnosticMXBean.class);
        System.out.printf("config=%s affinity.enable=%s idle.strategy=%s%n", configFile, config.enabled(), idleName);
        for (final String flag : new String[] {"UseLargePages", "UseTransparentHugePages", "UseNUMA", "AlwaysPreTouch",
                "UseZGC", "MaxHeapSize"}) {
            String value;
            try {
                value = hotspot.getVMOption(flag).getValue();
            } catch (final IllegalArgumentException platformSpecific) { // e.g. Linux-only flags elsewhere
                value = "n/a";
            }
            System.out.printf("  -XX:%s=%s%n", flag, value);
        }
        final Path meminfo = Path.of("/proc/meminfo");
        if (Files.isReadable(meminfo)) {
            Files.readAllLines(meminfo).stream()
                    .filter(l -> l.startsWith("HugePages_") || l.startsWith("Hugepagesize"))
                    .forEach(l -> System.out.println("  " + l));
        }
    }
}
