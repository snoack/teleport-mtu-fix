# teleport-mtu-fix

A script to fix UniFi Teleport VPN over connections with a low MTU on Linux.

By default Teleport enforces an MTU of 1420 which is too large for some
cellular networks (e.g. T-Mobile), causing fragmentation which renders the
connection unusably slow.

This script finds the routes added by Teleport and clamps their MTU setting.

## Usage

```sh
sudo ./teleport-mtu-fix.sh [--lan-only]
```

## LAN-only mode

By default the script only overrides the MTU of the default routes added by
Teleport, which routes all traffic over the VPN. With `--lan-only` the script
only routes traffic for the LAN subnet through the VPN.

This is useful if you only want to reach the remote LAN over the VPN without
sending all internet traffic through it.

### Configuring the LAN subnet

The subnet is defined at the top of the script:

```sh
LAN_SUBNET=192.168.1.0/24
```

Change this to match your remote network before deploying the script.

## Automatic execution with udev

Optionally, to run the script automatically whenever the Teleport VPN connects,
create a udev rule.

1. Create a udev rule in `/etc/udev/rules.d/99-teleport-mtu-fix.rules`:

   ```
   ACTION=="add", SUBSYSTEM=="net", KERNEL=="wg*", RUN+="/path/to/teleport-mtu-fix.sh --wait"
   ```

   1. Replace the path to the script.
   2. Optionally, append `--lan-only` to the path to enable LAN-only mode.

2. Reload the udev rules to take effect immediately:

   ```sh
   sudo udevadm control --reload-rules
   ```
