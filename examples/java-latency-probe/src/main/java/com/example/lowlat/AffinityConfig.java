package com.example.lowlat;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

/**
 * Thread role -> CPU mapping, read from a properties file.
 *
 * <pre>
 * affinity.enable=true
 * ping.cpu.affinity=9
 * pong.cpu.affinity=11
 * </pre>
 *
 * With affinity disabled (VMs, laptops, CI) every lookup returns -1 and threads are
 * left to the scheduler. The launcher uses the same switch to decide whether to add
 * the huge page / NUMA / pre-touch JVM flags.
 */
public final class AffinityConfig {

    private final Properties properties;
    private final boolean enabled;

    private AffinityConfig(final Properties properties) {
        this.properties = properties;
        this.enabled = Boolean.parseBoolean(properties.getProperty("affinity.enable", "false"));
    }

    public static AffinityConfig load(final Path file) throws IOException {
        final Properties properties = new Properties();
        if (Files.exists(file)) {
            try (InputStream in = Files.newInputStream(file)) {
                properties.load(in);
            }
        }
        return new AffinityConfig(properties);
    }

    public boolean enabled() {
        return enabled;
    }

    /** CPU for a role, or -1 when affinity is disabled or the role is not mapped. */
    public int cpuFor(final String role) {
        if (!enabled) {
            return -1;
        }
        final String value = properties.getProperty(role + ".cpu.affinity");
        return value == null || value.isBlank() ? -1 : Integer.parseInt(value.trim());
    }

    public String get(final String key, final String defaultValue) {
        return properties.getProperty(key, defaultValue);
    }
}
