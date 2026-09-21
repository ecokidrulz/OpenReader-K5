# OpenReader-K5 v0.1.0

Initial public release of the Kindle Touch / K5 port of OpenReader.

## Supported target

- Kindle Touch / K5 (`yoshi`)
- Kindle firmware 5.3.7.3
- KOReader installed separately
- Existing jailbreak/root environment required

The installer intentionally refuses unsupported hardware and firmware.

## Highlights

- Delayed takeover of the stock Kindle framework after boot
- Lightweight OpenReader launcher
- KOReader launch and return
- Full-screen Display Clock
- System Information screen
- Header clock and battery display
- One-shot **Boot KindleOS Once** recovery
- Boot watchdog and repeated-failure fallback
- Wake/redraw handling
- Persistent timekeeping support for older K5 hardware
- Optional integration with NiLuJe USBNetwork and `linkss`

## Installation safety

The v0.1.0 installer:

- validates the release payload
- validates the supported K5/5.3.7.3 target
- checks KOReader/FBInk prerequisites
- refuses to replace a running OpenReader session
- backs up an existing installation
- stages and verifies the new runtime before activation
- installs the Upstart boot configuration last
- limits the root-filesystem read/write window
- restores the root filesystem to read-only mode
- does not reboot automatically

Backups are stored under:

```text
/mnt/us/openreader-k5-backups/
```

## Uninstall behavior

`uninstall.sh` disables automatic OpenReader boot by removing the OpenReader Upstart configuration.

It intentionally retains:

```text
/mnt/us/extensions/openReader
/mnt/us/koreader
/mnt/us/.openreader
```

This allows KindleOS to boot normally without destroying the installed OpenReader or KOReader files.

## Tested lifecycle

The following round-trip was tested successfully on the supported Kindle Touch / K5:

```text
existing development installation
→ install v0.1.0
→ boot OpenReader
→ Boot KindleOS Once
→ uninstall automatic OpenReader boot
→ reboot into KindleOS
→ reinstall v0.1.0
→ reboot
→ OpenReader returns
```

The installed runtime was also compared byte-for-byte with the packaged release payload.

## Recovery

Before installation, users should verify root SSH access to stock KindleOS.

The README documents the tested Linux USBNetwork workflow, including toggling NiLuJe USBNetwork from KindleOS using:

```text
;un
```

in the Kindle search bar.

A manual one-shot KindleOS recovery marker is also available:

```text
/mnt/us/BOOT_KINDLEOS
```

## Known limitations

- v0.1.0 supports only Kindle Touch / K5 on firmware 5.3.7.3.
- KOReader is required but not bundled.
- OpenReader-K5 does not provide a jailbreak.
- USBNetwork and `linkss` are not bundled.
- Host-side setup documentation is currently Linux-focused.
- Windows and macOS USB-networking workflows are not yet documented or validated.
- K5 timezone handling may use a fixed UTC offset rather than a modern DST-aware timezone database.

## Credits

OpenReader-K5 is based on OpenReader by `terpinedream` and interoperates with software from the Kindle homebrew community, including KOReader, FBInk, NiLuJe USBNetwork, and NiLuJe `linkss`.

See the repository README and included license for details.
