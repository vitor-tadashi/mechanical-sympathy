package com.example.lowlat;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.StructLayout;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.VarHandle;
import java.util.Optional;

/**
 * Per-thread CPU affinity through the Foreign Function &amp; Memory API (Linux, glibc).
 *
 * <pre>
 * int sched_setaffinity(pid_t pid, size_t cpusetsize, const cpu_set_t *mask);
 * int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask);
 * int sched_getcpu(void);
 * </pre>
 *
 * {@code pid == 0} means the calling thread, so each call affects only the thread that makes it.
 * The JVM must be started with {@code --enable-native-access=ALL-UNNAMED}. On other operating
 * systems {@link #isSupported()} is false: pinning throws, the queries return -1 / "n/a".
 */
public final class ThreadAffinity {

    /** glibc's cpu_set_t: 1024 bits. */
    private static final int CPU_SETSIZE = 1024;
    private static final long CPU_SET_BYTES = CPU_SETSIZE / Byte.SIZE;

    private static final Linker LINKER = Linker.nativeLinker();
    private static final StructLayout CALL_STATE = Linker.Option.captureStateLayout();
    private static final VarHandle ERRNO = CALL_STATE.varHandle(MemoryLayout.PathElement.groupElement("errno"));

    private static final MethodHandle SCHED_SETAFFINITY = downcall("sched_setaffinity",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS),
            true);
    private static final MethodHandle SCHED_GETAFFINITY = downcall("sched_getaffinity",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS),
            true);
    private static final MethodHandle SCHED_GETCPU = downcall("sched_getcpu",
            FunctionDescriptor.of(ValueLayout.JAVA_INT), false);

    private ThreadAffinity() {
    }

    public static boolean isSupported() {
        return SCHED_SETAFFINITY != null && SCHED_GETAFFINITY != null && SCHED_GETCPU != null;
    }

    /** Restricts the calling thread to exactly one CPU. */
    public static void pinCurrentThread(final int cpu) {
        if (!isSupported()) {
            throw new UnsupportedOperationException("thread affinity needs Linux (sched_setaffinity)");
        }
        if (cpu < 0 || cpu >= CPU_SETSIZE) {
            throw new IllegalArgumentException("cpu out of range: " + cpu);
        }
        try (Arena arena = Arena.ofConfined()) {
            final MemorySegment mask = arena.allocate(CPU_SET_BYTES, Long.BYTES); // zeroed
            final long word = mask.getAtIndex(ValueLayout.JAVA_LONG, cpu / Long.SIZE);
            mask.setAtIndex(ValueLayout.JAVA_LONG, cpu / Long.SIZE, word | 1L << (cpu % Long.SIZE));
            final MemorySegment state = arena.allocate(CALL_STATE);
            final int rc = (int) SCHED_SETAFFINITY.invokeExact(state, 0, CPU_SET_BYTES, mask);
            if (rc != 0) {
                // EINVAL: the CPU is offline or outside this process's cpuset (cgroup)
                throw new IllegalStateException("sched_setaffinity(cpu=" + cpu + ") failed: errno="
                        + (int) ERRNO.get(state, 0L));
            }
        } catch (final RuntimeException | Error e) {
            throw e;
        } catch (final Throwable t) {
            throw new IllegalStateException(t);
        }
    }

    /** CPU the calling thread is running on now, or -1 when unknown. */
    public static int currentCpu() {
        if (SCHED_GETCPU == null) {
            return -1;
        }
        try {
            return (int) SCHED_GETCPU.invokeExact();
        } catch (final Throwable t) {
            return -1;
        }
    }

    /** Allowed CPUs of the calling thread as a list, e.g. {@code {9}} or {@code {0-2,4}}; "n/a" when unknown. */
    public static String currentAffinity() {
        if (SCHED_GETAFFINITY == null) {
            return "n/a";
        }
        try (Arena arena = Arena.ofConfined()) {
            final MemorySegment mask = arena.allocate(CPU_SET_BYTES, Long.BYTES);
            final MemorySegment state = arena.allocate(CALL_STATE);
            final int rc = (int) SCHED_GETAFFINITY.invokeExact(state, 0, CPU_SET_BYTES, mask);
            return rc == 0 ? format(mask) : "n/a";
        } catch (final Throwable t) {
            return "n/a";
        }
    }

    private static String format(final MemorySegment mask) {
        final StringBuilder sb = new StringBuilder("{");
        int cpu = 0;
        while (cpu < CPU_SETSIZE) {
            if (!isSet(mask, cpu)) {
                cpu++;
                continue;
            }
            final int first = cpu;
            while (cpu + 1 < CPU_SETSIZE && isSet(mask, cpu + 1)) {
                cpu++;
            }
            sb.append(sb.length() > 1 ? "," : "").append(first);
            if (cpu > first) {
                sb.append('-').append(cpu);
            }
            cpu++;
        }
        return sb.append('}').toString();
    }

    private static boolean isSet(final MemorySegment mask, final int cpu) {
        return (mask.getAtIndex(ValueLayout.JAVA_LONG, cpu / Long.SIZE) & 1L << (cpu % Long.SIZE)) != 0;
    }

    /** Handle for a libc function, or null when the symbol does not exist (non-Linux). */
    @SuppressWarnings("restricted") // native access is enabled by the launcher (--enable-native-access)
    private static MethodHandle downcall(final String name, final FunctionDescriptor descriptor, final boolean captureErrno) {
        final Optional<MemorySegment> symbol = LINKER.defaultLookup().find(name);
        if (symbol.isEmpty()) {
            return null;
        }
        return captureErrno
                ? LINKER.downcallHandle(symbol.get(), descriptor, Linker.Option.captureCallState("errno"))
                : LINKER.downcallHandle(symbol.get(), descriptor);
    }
}
