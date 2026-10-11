# iStoreOS + OpenClash image

Container image for the homelab iStoreOS router service: an apk-based iStoreOS rootfs
with the OpenClash LuCI app and the Mihomo (`clash_meta`) core baked in.

Only the image build lives here. The Dokploy deployment — compose, domain, password —
lives in the homelab repository under `dokploy/istoreos/`, which is the source of truth
for production.

## Layout

| Path | Lands at | Purpose |
| --- | --- | --- |
| `Dockerfile` | — | Builds on `xkand/istoreos:latest` (iStoreOS 25.12.5, apk) |
| `files/preinit-container.conf` | `/lib/preinit/99_zz_container.conf` | Disables the preinit "rescue IP" flow, which would flush eth0 and drop the Docker-assigned address |
| `files/network` | `/etc/config/network` | Loopback-only; declaring `eth0` here makes netifd clear its address |
| `files/rc.local` | `/etc/rc.local` | Re-applies the OpenClash settings on boot, after LuCI may have reset them |
| `luci-app-openclash-0.47.156.apk` | — | OpenClash LuCI app, installed with `apk add --allow-untrusted` (not in the trusted signing keys) |
| `OpenClash_0.47.156+x86_64_core.run` | — | Makeself bundle; only `clash_meta` is extracted into `/etc/openclash/core/` and smoke-tested with `-v` |

The image also disables the device-oriented services (hostapd, wpa_supplicant,
dnsmasq, odhcpd, dropbear, dockerd, quickstart) and neutralises
`/usr/libexec/rescan_nic.sh`, which would otherwise rewrite `/etc/config/network` on
first boot.

## Build and publish

`.github/workflows/image.yml` builds and pushes on every push to `main`:

- `ghcr.io/kevinpan45/istoreos-openclash-image:latest`
- `ghcr.io/kevinpan45/istoreos-openclash-image:<commit sha>`

The image is large (roughly 840 MB) and the base image `xkand/istoreos:latest` is
built from the official `.img.gz`, so the first build takes a few minutes.

Local build (needs the base image; it cannot always be pulled over a slow link):

```sh
docker build -t istoreos-openclash:local .
```

## Runtime notes

- The container needs `cap_add: [NET_ADMIN]` and publishes `7890`, which other homelab
  services use as an HTTP proxy. Traffic is *not* transparently intercepted unless
  iStoreOS is used as the gateway of those containers.
- fw4's default `input policy drop` rejects Traefik traffic from `dokploy-network`, so
  the image sets `firewall.@defaults[0].input='ACCEPT'` while keeping the firewall
  enabled — OpenClash needs the `inet fw4` table to exist at startup.
- `openclash.config.lan_interface_name='eth0'` is required because the loopback-only
  network config leaves the LAN interface autodetection with nothing to read.

## Deploying a new build

Deployment state the image does not contain — the imported OpenClash subscription in
`/etc/openclash/config/` and the generated `openclash.@authentication` section — lives
in the container's writable layer. **Recreating the container discards it**, so treat a
rollout as a maintenance window and re-import the subscription afterwards. See
`dokploy/istoreos/README.md` in the homelab repository.

