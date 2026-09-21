# USBNetwork + SSH from Linux

These steps were used during OpenReader-K5 v0.1.0 development on Linux Mint/Ubuntu-style systems.

## 1. Enable USBNetwork on the Kindle

From stock KindleOS, enter `;un` in the search bar and submit it, then connect the Kindle by USB.

## 2. Identify the USB Ethernet interface

```bash
ip link
```

Look for a newly created interface such as `usb0` or `enx...`.

## 3. Configure the host address

Replace the interface name below with your actual interface:

```bash
sudo nmcli dev set enxee4900000000 managed no
sudo ip addr flush dev enxee4900000000
sudo ip addr add 192.168.15.201/24 dev enxee4900000000
sudo ip link set enxee4900000000 up
```

## 4. Test connectivity

```bash
ping 192.168.15.244
ssh root@192.168.15.244
```

If SSH reports a stale host key for the intended Kindle:

```bash
ssh-keygen -R 192.168.15.244
```
