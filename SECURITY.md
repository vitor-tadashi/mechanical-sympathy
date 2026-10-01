# Security policy

This page is about reporting problems. How the scripts protect a host, and how you undo their changes, is in [SAFETY.md](SAFETY.md).

## What this repository can do to a host

The guides and scripts change kernel arguments, CPU and interrupt affinity, firewall rules and, on request, CPU vulnerability mitigations. A wrong recommendation can lock you out of a host, break boot or remove a security control. Treat a bad instruction here as a security issue.

Settings that lower security are opt-in and marked with `> [!CAUTION]`. Examples are turning mitigations off ([Guide 01 §5.6](guides/01-grub-bootloader-tuning.md#56-iommu-and-cpu-vulnerability-mitigations-security-sensitive)) and removing host packet filtering ([Guide 07 §6](guides/07-os-hygiene.md#6-opt-in-removing-host-packet-filtering)).

## What to report privately

- A script that does more than its guide says, or acts outside `/etc/lowlat` and `/var/lib/lowlat` without saying so.
- A default that weakens security without the `CAUTION` marker.
- A command in a guide that can be triggered by untrusted input (for example an unquoted value read from a file).
- A leaked secret, host name, address or private identifier in a file or in the Git history.

## How to report

Use GitHub's private vulnerability reporting: open the **Security** tab of the repository and choose **Report a vulnerability**. If that is not available, open an issue that says only "security report, please contact me" and leave out the details. You should get a first answer within 7 days.

## What is not a vulnerability

A tuning trade-off that the text already documents, such as higher power use or lower throughput, is not a vulnerability. Report it as an ordinary issue if the explanation is unclear.
