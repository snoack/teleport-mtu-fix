# teleport-mtu-fix

A script to fix UniFi Teleport VPN over connections with a low MTU on Linux.

By default Teleport enforces an MTU of 1420 which is too large for some
cellular networks (e.g. T-Mobile), causing fragmentation which renders the
connection unusably slow.

This script finds the routes added by Teleport and clamps their MTU setting.

## Usage

```sh
sudo ./teleport-mtu-fix.sh [--lan-only] [--wait-for-route] [--wait-for-gateway]
```

## LAN-only mode

By default the script only overrides the MTU of the default routes added by
Teleport, which routes all traffic over the VPN. With `--lan-only` the script
only routes traffic for the LAN subnet through the VPN.

This is useful if you only want to reach the remote LAN over the VPN without
sending all internet traffic through it.

## Configuration

The LAN subnet and gateway probe address are defined at the top of the script:

```sh
LAN_SUBNET=192.168.1.0/24
GATEWAY_ADDRESS=192.168.1.1
```

`LAN_SUBNET` only needs to be changed when using `--lan-only`.
`GATEWAY_ADDRESS` only needs to be changed when using `--wait-for-gateway`.

## Automatic execution with udev

Optionally, to run the script automatically whenever the Teleport VPN connects,
create a udev rule.

1. Create a udev rule in `/etc/udev/rules.d/99-teleport-mtu-fix.rules`:

   ```
   ACTION=="add", SUBSYSTEM=="net", KERNEL=="wg*", RUN+="/path/to/teleport-mtu-fix.sh --wait-for-route"
   ```

   1. Replace the path to the script.
   2. Optional: append `--lan-only` to the path to enable LAN-only mode.
   3. Optional: if `--wait-for-route` does not work reliably on your system, try `--wait-for-gateway` instead.


2. Reload the udev rules to take effect immediately:

   ```sh
   sudo udevadm control --reload-rules
   ```
