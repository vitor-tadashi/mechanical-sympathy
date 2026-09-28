package com.example.lowlat;

import java.util.concurrent.locks.LockSupport;

/**
 * What a polling thread does when there is no work.
 *
 * <ul>
 *   <li>{@code spin}: bare metal, isolated CPU. Lowest wake-up latency, burns the core.</li>
 *   <li>{@code backoff}: shared CPUs / VMs. Spin briefly, then yield, then park.</li>
 * </ul>
 */
public interface IdleStrategy {

    /** @param workCount work done in the last iteration; 0 means idle. */
    void idle(int workCount);

    static IdleStrategy of(String name) {
        return switch (name) {
            case "spin" -> workCount -> {
                if (workCount == 0) {
                    Thread.onSpinWait(); // PAUSE on x86: saves power, helps the SMT sibling
                }
            };
            case "backoff" -> new BackoffIdleStrategy();
            default -> throw new IllegalArgumentException("unknown idle strategy: " + name);
        };
    }

    final class BackoffIdleStrategy implements IdleStrategy {
        private static final int SPINS = 100;
        private static final int YIELDS = 10;
        private static final long MIN_PARK_NS = 1_000;
        private static final long MAX_PARK_NS = 100_000;

        private int idleCount;
        private long parkNs = MIN_PARK_NS;

        @Override
        public void idle(int workCount) {
            if (workCount > 0) {
                idleCount = 0;
                parkNs = MIN_PARK_NS;
                return;
            }
            idleCount++;
            if (idleCount <= SPINS) {
                Thread.onSpinWait();
            } else if (idleCount <= SPINS + YIELDS) {
                Thread.yield();
            } else {
                LockSupport.parkNanos(parkNs);
                parkNs = Math.min(parkNs << 1, MAX_PARK_NS);
            }
        }
    }
}
