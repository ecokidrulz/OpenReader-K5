# USBNetwork + SSH from macOS

> **Project status:** Based on established Kindle USBNetwork guidance; not yet validated by the OpenReader-K5 project on current macOS hardware.

## 1. Enable USBNetwork

From stock KindleOS, enter `;un` in the search bar and submit it, then connect the Kindle by USB.

## 2. Configure the USB Ethernet interface

Open **System Settings → Network** and select the Kindle USB Ethernet interface. Older documentation may identify it as **RNDIS/Ethernet Gadget**.

Configure IPv4 manually:

```text
IP address:  192.168.15.201
Subnet mask: 255.255.255.0
Router:      leave blank
```

## 3. Connect

In Terminal:

```bash
ping 192.168.15.244
ssh root@192.168.15.244
```

If no USB Ethernet interface appears, resolve USB-network recognition first; SSH cannot work until the network interface exists.
