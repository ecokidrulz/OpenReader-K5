# OpenReader-K5 v0.1.2

OpenReader-K5 v0.1.2 is a tested runtime and interface update for Kindle Touch / K5 firmware 5.3.7.3.

v0.1.1 was a documentation/presentation-only release. v0.1.2 contains the first runtime changes since v0.1.0.

## Highlights

### Wi-Fi connectivity

OpenReader now retains the Kindle service required to maintain normal Wi-Fi routing and DNS while the Amazon framework is stopped.

Validated functions include:

- Wi-Fi connectivity under OpenReader
- Wi-Fi connectivity under KOReader
- wireless Calibre connection
- Wi-Fi recovery after KOReader sleep/wake

Wi-Fi networks and credentials must first be configured in stock KindleOS. OpenReader-K5 uses the Kindle's existing wireless configuration and does not provide its own Wi-Fi setup interface.

### USB Network and Storage feedback

The lower toolbar now provides clearer status and transition screens for:

- USBNetwork already active
- enabling USBNetwork
- USBNetwork success/failure
- USB storage transition
- USB storage eject/return
- unavailable USBNetwork installation

USB result screens remain visible for approximately five seconds before returning to OpenReader.

### Confirmation screens

Updated confirmation interfaces are provided for:

- Boot KindleOS Once
- Reboot
- Power Off

The controls use the lower portion of the display with separate Cancel and action areas.

### Power-off screen

The final shutdown screen has been revised for the K5 display and now clearly indicates that the Kindle is powered off and can be restarted with the power button.

### EPDC framebuffer recovery

A defensive K5-specific framebuffer recovery helper has been added.

On this hardware, the EPDC framebuffer was observed on rare occasions to remain explicitly paused after a power/display transition. OpenReader now checks for that condition during initial startup and after wake and resumes the framebuffer only when the driver reports it as paused.

Normal boots and wake events are unaffected when recovery is unnecessary.

## Tested working

The following have been tested successfully on the supported Kindle Touch / K5:

- installation and automatic OpenReader boot
- repeated normal reboot cycles
- KOReader launch and return
- Display Clock
- System Info
- timed screensaver / sleep and wake
- Wi-Fi connectivity
- wireless Calibre connection
- USBNetwork mode
- USB storage mode and safe return
- Reboot confirmation and reboot
- Power Off confirmation and shutdown
- Boot KindleOS Once
- return to OpenReader after KindleOS
- custom screensaver integration with `linkss`

## Requirements

Tested configuration:

- Kindle Touch / K5 (`yoshi`)
- Kindle firmware 5.3.7.3
- existing jailbreak / root-capable environment
- KOReader installed under `/mnt/us/koreader`
- NiLuJe USBNetwork strongly recommended for recovery and maintenance

OpenReader-K5 does not provide a jailbreak, KOReader, USBNetwork, or Wi-Fi configuration interface.

## Wi-Fi setup note

Wireless networks, passwords, and related Wi-Fi settings should be configured in stock KindleOS before using OpenReader.

To change Wi-Fi settings later:

1. choose **Boot KindleOS Once** from OpenReader;
2. update the Wi-Fi configuration in KindleOS;
3. reboot normally to return to OpenReader.

## Compatibility

v0.1.2 remains intentionally restricted to:

- Kindle Touch / K5
- firmware 5.3.7.3

Other Kindle models and firmware versions are not supported by this release installer.
