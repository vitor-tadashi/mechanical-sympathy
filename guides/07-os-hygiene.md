# Guide 07 — Operating System Hygiene

> **Script:** [`scripts/07-os-hygiene`](../scripts/07-os-hygiene) · **Previous:** [Guide 06](06-kernel-sysctl-tuning.md) · **Then:** [`scripts/verify-tuning`](../scripts/verify-tuning)

| | |
|---|---|
| **Risk level** | **2 / 5** for services, limits, noatime and tuned. **5 / 5** for the opt-in firewall and netfilter section (§6): that removes a security control. |
| **Reboot required** | No |
| **Applies to** | Bare metal and VMs |

---

## 1. Why

After Guides 01–06, the isolated CPUs are quiet. This guide reduces what happens **everywhere else**: periodic jobs, idle-time daemons, metadata writes, power management, and packet-filter hooks on the network path. None of these are large on their own. Together they are the background noise that shows up as unexplained p99.9 spikes on the housekeeping CPUs, where your NIC interrupts are served.

## 2. Services

`disable_unnecessary_services` stops and disables everything in `DISABLE_SERVICES` (in `lowlat.conf`). The reference list, and why each entry is there:

| Service(s) | What it does | Why disable it |
|---|---|---|
| `crond` | Periodic jobs | Unplanned work at arbitrary times (package-cache refreshes, report scripts, `sa1`). Move the jobs you need to systemd timers in `housekeeping.slice` ([Guide 05](05-cgroup-isolation.md)). ⚠️ On RHEL 8, **logrotate runs from cron** (`/etc/cron.daily/logrotate`). Enable `logrotate.timer`, or keep a timer for it. On RHEL 9 logrotate is already a systemd timer. |
| `plymouth-*` | Boot splash screen | No console to show it on. Pure boot-time and shutdown overhead. |
| `rpcbind`, `rpc-statd-notify`, `auth-rpcgss-module`, `rpc_pipefs`, `nfs-client.target`, `remote-fs-pre.target` | NFS client plumbing | Not needed unless the host mounts NFS. Also a network-facing service with its own timers. |
| `sysstat-collect.timer`, `sysstat-summary.timer` | `sar` data collection every 10 min | Periodic `/proc` walks. Keep them if `sar` is your capacity-planning tool, and move them into `housekeeping.slice`. |
| `pcscd` | Smart-card daemon | No smart cards on servers |
| `cpupower`, `cpuspeed`, `cpufreqd`, `powerd` | Frequency/power daemons | They fight the fixed `performance` governor that tuned sets (§5) |
| **EDR / antivirus / cloud agents** | Security and management agents | **Do not disable them without your security team.** Either the site policy allows turning them off on trading hosts (and then do it, add them to the list), or confine them: [Guide 05](05-cgroup-isolation.md) slice plus pinning. A launcher that **refuses to start** while such an agent is running, unless the environment explicitly allows it, is a useful guard rail in production. |

`firewalld` has its own switch (`DISABLE_FIREWALLD`, default `no`). See §6.

`rsyslog` is kept **on** (`ensure_rsyslog`). Local logging is cheap, runs on OS CPUs, and without it you lose the kernel messages you need during an incident.

## 3. Resource limits

`/etc/security/limits.d/90-lowlat.conf` (for login sessions, via PAM):

```text
@app-user  soft  nproc    65535
@app-user  hard  nproc    65535
@app-user  soft  nofile   65535
@app-user  hard  nofile   65535
@app-user  -     rtprio   99
@app-user  -     nice     -20
@app-user  -     memlock  unlimited
```

| Limit | Why |
|---|---|
| `nofile` | Sockets + journal/log files + memory-mapped files per process. The default 1024 is too low for a gateway. |
| `nproc` | Threads count against `nproc`. JVMs with many pools can hit the default. |
| `rtprio` | Lets the application set `SCHED_FIFO` on its own threads without root ([Guide 02 §6.5](02-cpu-core-isolation.md#65-real-time-scheduling-class-usually-unnecessary)) |
| `nice` | Lets it raise the priority of its non-critical threads |
| `memlock` | `mlockall()` the process so that page-cache pressure can never evict its code or non-huge-page data |

Scope matters. Some scripts truncate `/etc/security/limits.conf` and write `* - rtprio 99` for **every** user. Here the limits apply only to the application's group, in a separate file, and `limits.conf` is left alone.

These limits apply to **PAM sessions** (SSH logins, `su -`). Services started by systemd do **not** read `limits.d`. Use `LimitNOFILE=`, `LimitRTPRIO=`, `LimitMEMLOCK=` in the unit ([Guide 05 §4.4](05-cgroup-isolation.md#44-the-cpuset-trap)), or `DefaultLimit*=` in `system.conf` ([Guide 02 §4.1](02-cpu-core-isolation.md#41-systemd-cpuaffinity-persistent)).

## 4. `noatime`

By default (`relatime`), reading a file can still update its access time on disk, which means a metadata write, a journal transaction, and eventually I/O. `set_noatime_mounts` adds `noatime` to local `xfs`/`ext4` entries in `/etc/fstab` and remounts them. (`noatime` implies `nodiratime`.) Swap, tmpfs, NFS and other types are left alone.

Side effect: tools that rely on atime, such as some mail readers and `tmpwatch` in atime mode, see stale values. That is irrelevant on a trading host.

## 5. tuned profile

`tuned` applies a coherent set of power and latency settings, and re-applies them at every boot. The script installs a custom profile, `/etc/tuned/low-latency/tuned.conf`:

```ini
[main]
summary=Low latency: network-latency + mechanical-sympathy host settings
include=network-latency

[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100
```

What `network-latency` brings (through `latency-performance`):

| Setting | Effect |
|---|---|
| `force_latency` (PM QoS) | Holds `/dev/cpu_dma_latency` open with a very low value, so cpuidle cannot pick deep C-states. This is redundant with `idle=poll` on bare metal, and it is the main C-state control in VMs. |
| `governor=performance` | Fixed maximum frequency (with `acpi-cpufreq` after `intel_pstate=disable`, [Guide 01](01-grub-bootloader-tuning.md#53-frequency-and-power)) |
| `transparent_hugepages=never` | Same as the boot argument |
| `kernel.numa_balancing=0` | Same as [Guide 06](06-kernel-sysctl-tuning.md#2-kernel-logging-and-debug) |
| `net.core.busy_read=50`, `net.core.busy_poll=50` | **Busy polling** for all sockets: a blocking `recv`/`poll` spins on the NIC queue for up to 50 µs before sleeping ([Guide 04 §6.1](04-network-optimization.md#61-choosing-the-cpu), model B) |
| `net.ipv4.tcp_fastopen=3` | Same as Guide 06 |

**Ordering with Guide 06.** tuned applies its `[sysctl]` values and then, because `reapply_sysctl = 1` is the default in `/etc/tuned/tuned-main.conf`, re-applies `/etc/sysctl.d/`. So on any conflict the Guide 06 file wins, and the script makes sure the option has not been turned off. Some scripts run `tuned-adm profile network-latency` *before* writing their sysctls with `sysctl -w`. That works until the next reboot, when tuned and the missing persistence change the result.

```bash
tuned-adm active                  # Current active profile: low-latency
tuned-adm verify                  # checks that the profile's settings are in effect
```

## 6. Opt-in: removing host packet filtering

⚠️ **This section removes a security control. It is disabled by default.**

Every packet traverses the netfilter hooks. With connection tracking loaded, each packet also does a conntrack table lookup/insert (hashing, locking, per-flow state, timers), even if the rule set is empty. On a gateway handling millions of small messages, removing that per-packet work, and the conntrack table's garbage-collection work, is measurable, typically a few hundred ns to a few µs per packet in the tail.

Reference implementations do three things, which map to three switches:

| Switch | What it does |
|---|---|
| `DISABLE_FIREWALLD=yes` | Stops and disables firewalld |
| `FLUSH_FIREWALL_RULES=yes` | Flushes nftables and iptables/ip6tables in all tables, deletes user chains, and sets policies to ACCEPT |
| `REMOVE_NETFILTER_MODULES=yes` | Unloads NAT, conntrack helpers, `xt_*` matches, `ip_tables`/`ip6_tables` (21 modules, in dependency order) |

**Preconditions. All of them must be true:**

- The host sits behind a **network firewall/ACL** that enforces the same policy (only the exchange, the internal peers, and the management network can reach it).
- The management network is separate ([Guide 04 §3](04-network-optimization.md#3-network-segmentation-give-each-traffic-class-its-own-nic)) and access-controlled.
- Your security team has approved it in writing, as an exception for this host class.
- No local service depends on NAT, masquerading, or port forwarding (containers, libvirt).

Alternatives with most of the benefit and less risk:

- Keep the firewall, but exempt the critical flows from conntrack with `notrack` rules in the `raw` table. The rules still apply, but there is no per-flow state.
- Use kernel bypass for the critical NICs ([Guide 04 §7](04-network-optimization.md#7-kernel-bypass-optional)). Those packets never reach netfilter.

Module unloading and rule flushing are **not persistent**. When opted in, `lowlat-runtime.service` repeats them at every boot (`07-os-hygiene --runtime`). To make module removal stick, blacklist them in `/etc/modprobe.d/` (`install <module> /bin/false`) as well.

## 7. Things this guide deliberately does *not* do

| Seen in the wild | Why not here |
|---|---|
| `rm /dev/random && ln -s /dev/urandom /dev/random` | Since kernel 5.6, and in the RHEL 8 backport, `/dev/random` only blocks until the CRNG is initialised at early boot, so it no longer blocks in normal operation. The symlink is also lost at every boot (devtmpfs). For Java, use `-Djava.security.egd=file:/dev/urandom` (the `file:/dev/./urandom` spelling is a workaround for very old JDKs). |
| Killing all application processes before tuning | Tuning must be applied **before** the application starts, at boot, by `lowlat-runtime.service`. A tuning script that kills production processes is a hazard. Apply changes in a maintenance window instead. |
| Re-running the whole tuning script from `rc.local` | No ordering, no status, and it re-does persistent steps (GRUB, file edits) on every boot. Only runtime state is re-applied at boot, by a systemd unit ([`scripts/systemd/lowlat-runtime.service`](../scripts/systemd/lowlat-runtime.service)). |

## 8. Using the script

```bash
scripts/07-os-hygiene --dry-run
sudo scripts/07-os-hygiene --apply
scripts/07-os-hygiene --verify
```

## 9. Verification

```bash
systemctl list-units --type=service --state=running --no-pager      # what is left running
systemctl list-timers --all --no-pager                              # periodic work
ulimit -a        # as app-user in a new SSH session: nofile, nproc, rtprio, memlock
findmnt -t xfs,ext4 -o TARGET,OPTIONS                               # noatime
tuned-adm active && tuned-adm verify
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor          # performance
nft list ruleset | head; iptables -S | head; lsmod | grep -E 'nf_conntrack|ip_tables'
```

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Logs no longer rotated (RHEL 8) | `crond` disabled | `systemctl enable --now logrotate.timer` (or keep a cron replacement timer) |
| `ulimit -n` still 1024 in a service | Services do not read `limits.d` | `LimitNOFILE=` in the unit |
| `tuned-adm verify` fails | Another profile or a manual change overrides a setting | `tuned-adm profile low-latency`; check `/var/log/tuned/tuned.log` |
| `modprobe -r` "Module is in use" | Rules or another module still reference it | Flush rules first; containers/libvirt may hold them |
| Remote access lost after flushing rules | Policy was ACCEPT but a network ACL relied on host state | Use the out-of-band console; restore with `systemctl start firewalld` |

## 11. Rollback

```bash
sudo systemctl enable --now crond sysstat-collect.timer sysstat-summary.timer   # as needed
sudo rm -f /etc/security/limits.d/90-lowlat.conf
sudo tuned-adm profile throughput-performance        # the RHEL server default
sudo cp /var/lib/lowlat/factory-settings/etc/fstab /etc/fstab
sudo systemctl enable --now firewalld                 # if it was disabled
```

## 12. References

- `man 7 tuned-profiles`, `man 5 tuned-main.conf`, `man 5 limits.conf`, `man 8 mount` (`noatime`)
- Red Hat — *Monitoring and managing system status and performance*: "Getting started with TuneD"
- `man 8 nft` (`notrack`), <https://docs.kernel.org/networking/nf_conntrack-sysctl.html>
