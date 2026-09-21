# USBNetwork + SSH from Windows 10/11

> **Project status:** Based on established Kindle USBNetwork/RNDIS guidance; not yet validated by the OpenReader-K5 project on Windows 10/11.

## 1. Enable USBNetwork

From stock KindleOS, enter `;un` in the search bar and submit it, then connect the Kindle by USB.

## 2. Confirm Windows sees a USB network adapter

In **Device Manager**, look under **Network adapters** for an entry such as `RNDIS/Ethernet Gadget`, `USB Ethernet/RNDIS Gadget`, or `Kindle USB RNDIS Device`.

If no usable network adapter appears, resolve the RNDIS/driver issue before continuing.

## 3. Assign the host IPv4 address

Open **Control Panel → Network and Internet → Network and Sharing Center → Change adapter settings**.

Open the Kindle/RNDIS adapter properties, select **Internet Protocol Version 4 (TCP/IPv4)**, and set:

```text
IP address:      192.168.15.201
Subnet mask:     255.255.255.0
Default gateway: leave blank
```

## 4. Test connectivity

In PowerShell:

```powershell
ping 192.168.15.244
ssh root@192.168.15.244
```

Useful diagnostics:

```powershell
Get-NetAdapter
Get-NetIPAddress -AddressFamily IPv4
Test-NetConnection 192.168.15.244 -Port 22
```
