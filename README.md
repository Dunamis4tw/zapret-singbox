# zapret-singbox

A Docker container combining [zapret](https://github.com/bol-van/zapret) (DPI bypass) and [sing-box](https://github.com/SagerNet/sing-box) (proxy server) into a single network gateway. Designed primarily for users in Russia to bypass internet censorship while routing traffic through a configurable proxy.

## How it works

```
Client → sing-box (port 7890) → zapret (DPI bypass) → Internet
```

sing-box accepts HTTP/SOCKS5 connections on port 7890. Traffic then passes through zapret which applies DPI circumvention strategies before reaching blocked resources.

## Requirements

- Docker & Docker Compose
- Linux host (iptables support required)
- A working sing-box config

## Quick Start

**1. Clone the repository**

```bash
git clone https://github.com/YOUR_USERNAME/zapret-singbox.git
cd zapret-singbox
```

**2. Add zapret strategies**

Clone a strategies pack into `./configs/zapret/`:

```bash
git clone https://github.com/Snowy-Fluffy/zapret.cfgs configs/zapret-src
cp -r configs/zapret-src/configurations/* configs/zapret/
```

Or place your own strategy files into `./configs/zapret/`.

**3. Configure sing-box**

Edit `./configs/sing-box/sing-box.conf` with your sing-box configuration. The container exposes port `7890` as a mixed (HTTP + SOCKS5) proxy by default.

**4. Set a strategy and start**

Open `docker-compose.yml` and set the desired strategy:

```yaml
environment:
  - ZAPRET_STRATEGY=general   # strategy filename from ./configs/zapret/
```

Then build and run:

```bash
./start.sh
# or manually:
docker compose up -d --build
```

## Management Scripts

| Script | Description |
|---|---|
| `./start.sh` | Build image and start the container |
| `./restart.sh` | Restart the container |
| `./switch_strategy.sh` | Interactive strategy switcher |
| `./test_strategies.sh` | Auto-test multiple strategies against a list of sites via proxy |
| `./blockcheck.sh` | Run zapret's built-in `blockcheck.sh` inside the container and save results |

### switch_strategy.sh

Displays all available strategies in a numbered list (with the current one highlighted), lets you pick one, patches `docker-compose.yml`, and restarts the container.

```bash
./switch_strategy.sh
```

### test_strategies.sh

Iterates through selected strategies, restarts the container for each, and checks a list of URLs through the proxy with `curl`. Results are printed to console and saved to `./strategy_test_results/`.

```bash
./test_strategies.sh
```

### blockcheck.sh

Stops zapret inside the running container and runs the built-in `blockcheck.sh` diagnostic tool interactively. Output is saved to `./blockcheck_results/` with a timestamp and current strategy name.

```bash
./blockcheck.sh
```

## Directory Structure

```
zapret-singbox/
├── configs/
│   ├── sing-box/
│   │   └── sing-box.conf       # Your sing-box config
│   └── zapret/                 # Strategy files (not tracked by git)
├── logs/
│   └── sing-box/               # sing-box logs (not tracked by git)
├── blockcheck_results/         # blockcheck output logs
├── strategy_test_results/      # strategy test output logs
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── start.sh
├── restart.sh
├── switch_strategy.sh
├── test_strategies.sh
└── blockcheck.sh
```

## Configuration

### docker-compose.yml

```yaml
services:
  zapret-singbox:
    environment:
      - ZAPRET_STRATEGY=general   # filename from ./configs/zapret/
    ports:
      - "7890:7890"               # proxy port
```

### Proxy settings

Point your client to:

```
HTTP proxy:   http://HOST_IP:7890
SOCKS5 proxy: socks5://HOST_IP:7890
```

## Build arguments

| ARG | Default | Description |
|---|---|---|
| `ZAPRET_VERSION` | `v72.10` | zapret release tag |
| `SINGBOX_VERSION` | `1.13.0` | sing-box release version |

To build with different versions:

```bash
docker compose build \
  --build-arg ZAPRET_VERSION=v72.11 \
  --build-arg SINGBOX_VERSION=1.13.1
```

## Sharing the image

**Archive project files** (excluding logs and strategy configs):

```bash
tar -czvf zapret-singbox.tar.gz \
    --exclude='./logs' \
    --exclude='./configs/zapret' \
    --exclude='.git' \
    --exclude='./strategy_test_results' \
    --exclude='./blockcheck_results' \
    .
```

**Export built Docker image** (no rebuild needed on recipient side):

```bash
docker save zapret-singbox-zapret-singbox | gzip > zapret-singbox-image.tar.gz
# recipient:
docker load < zapret-singbox-image.tar.gz
```

## Troubleshooting

**Container exits immediately** — check that `ZAPRET_STRATEGY` matches an existing file in `./configs/zapret/`.

**Port 7890 not accessible** — make sure no firewall is blocking the port on the host.

**All sites time out** — the sing-box config may be invalid or the strategy may not work for your ISP. Try `./switch_strategy.sh` or run `./blockcheck.sh` to find a working strategy.

**iptables errors in logs** — the container requires `privileged: true` in compose. Do not remove it.

## Credits

- [zapret](https://github.com/bol-van/zapret) by bol-van
- [sing-box](https://github.com/SagerNet/sing-box) by SagerNet
- Strategy configs: [Snowy-Fluffy/zapret.cfgs](https://github.com/Snowy-Fluffy/zapret.cfgs)

## License

MIT
