package com.example.lowlat;

import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;

/**
 * A single-writer sequence on its own cache line.
 *
 * Two sequences written by two different threads must never share a 64-byte line,
 * otherwise every write invalidates the other core's copy (false sharing). The
 * padding classes put 56+ bytes on both sides of {@code value}; class-hierarchy
 * padding is used because the JVM may reorder fields within one class but not
 * across a superclass boundary.
 */
public final class PaddedSequence extends PaddedSequenceValue {

    @SuppressWarnings("unused")
    private long p9, p10, p11, p12, p13, p14, p15;

    private static final VarHandle VALUE;

    static {
        try {
            VALUE = MethodHandles.lookup().findVarHandle(PaddedSequenceValue.class, "value", long.class);
        } catch (ReflectiveOperationException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    public PaddedSequence(long initial) {
        VALUE.setRelease(this, initial);
    }

    /** Acquire read: sees everything the writer did before its release write. */
    public long get() {
        return (long) VALUE.getAcquire(this);
    }

    /** Release write: cheaper than a volatile store (no StoreLoad fence on x86). */
    public void set(long v) {
        VALUE.setRelease(this, v);
    }
}

abstract class PaddedSequenceLhs {
    @SuppressWarnings("unused")
    private long p1, p2, p3, p4, p5, p6, p7;
}

abstract class PaddedSequenceValue extends PaddedSequenceLhs {
    protected long value;
}
