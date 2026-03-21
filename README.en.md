**English** | [Русский](README.md)
# zapret-singbox

A container that combines [zapret](https://github.com/bol-van/zapret) and [sing-box](https://github.com/SagerNet/sing-box) into an isolated environment. All traffic is proxied through sing-box, iptables inside the container intercepts it and passes it through zapret. The host system is not affected.

The primary purpose is convenient deployment of the zapret + sing-box bundle without installing anything on the host. Includes scripts for finding and testing strategies.

**DNS.** By default, sing-box uses DNS-over-HTTPS (`1.1.1.1`). This prevents the ISP from intercepting DNS queries.

---

## How It Works

```
Application  ──►  sing-box :7890  ──►  iptables NFQUEUE  ──►  zapret (nfqws)  ──►  Internet
                   mixed proxy          traffic intercept        DPI bypass
```

The application connects to the proxy on port `7890`. sing-box accepts the connection, iptables intercepts outgoing traffic via NFQUEUE and passes it to zapret, which applies the selected DPI bypass strategy.

---

## Running

### Option 1 — `docker run` (quick start, strategy already known)

```bash
docker run -d \
  --name zapret-singbox \
  --restart unless-stopped \
  --privileged \
  -e ZAPRET_STRATEGY=general_fake_tls_auto_alt_3 \
  -p 7890:7890 \
  ghcr.io/dunamis4tw/zapret-singbox:latest
```

> Management scripts do not work with this option — they require `docker-compose.yml`.

### Option 2 — `docker compose` (recommended; supports scripts, custom configs, logs)

Create the directory:

```bash
mkdir -p /opt/zapret-singbox && cd /opt/zapret-singbox
```

`docker-compose.yml`:

```yaml
services:
  zapret-singbox:
    image: ghcr.io/dunamis4tw/zapret-singbox:latest
    container_name: zapret-singbox
    restart: unless-stopped
    privileged: true
    environment:
      - ZAPRET_STRATEGY=general_fake_tls_auto_alt     # strategy to use
    ports:
      - "7890:7890"                                   # port exposed by the default sing-box config
    volumes:
      - ./configs/sing-box:/opt/sing-box/configs      # optional: custom sing-box config
      - ./configs/zapret:/opt/zapret/zapret.cfgs/configurations  # optional: custom zapret strategies
      - ./logs/sing-box:/opt/sing-box/logs            # optional: sing-box logs
```

Start:

```bash
docker compose up -d
```

After startup, the proxy is available at `localhost:7890` (HTTP and SOCKS5).

### Changing the Strategy

If `ZAPRET_STRATEGY` is not set, `general` is used. To change the strategy, edit `ZAPRET_STRATEGY` in `docker-compose.yml` and restart the container:

```bash
docker compose up -d
```

List available strategies:

```bash
docker compose exec zapret-singbox ls /opt/zapret/zapret.cfgs/configurations
```

To find the best strategy, use the `test_strategies.sh` script described in the [Scripts](#scripts) section.

<details>
<summary>Current strategy list</summary>

```
DiscordFix
DiscordFix_ALT
DiscordFix_ALT2
DiscordFix_для_МГТС
GeneralFix
GeneralFix_ALT
GeneralFix_ALT3
GeneralFix_ALT4
RussiaFix
UltimateFix
UltimateFix_ALT
UltimateFix_ALT_EXTENDED
UltimateFix_ALT_v10
UltimateFix_ALT_v2
UltimateFix_ALT_v3
UltimateFix_ALT_v4
UltimateFix_ALT_v5
UltimateFix_ALT_v6
UltimateFix_ALT_v7
UltimateFix_ALT_v8
UltimateFix_ALT_v9
UltimateFix_Universal
UltimateFix_Universal_v2
UltimateFix_Universal_v3
UltimateFix_для_МГТС
YoutubeFix_ALT
discord
fix_v1
fix_v2
fix_v3
general
general_ALT
general_ALT10
general_ALT11
general_ALT2
general_ALT3
general_ALT4
general_ALT5
general_ALT6
general_ALT7
general_ALT8
general_ALT9
general_fake_tls_auto
general_fake_tls_auto_alt
general_fake_tls_auto_alt_2
general_fake_tls_auto_alt_3
general_old
general_simple_fake
general_simple_fake_alt
general_simple_fake_alt2
general_МГТС
general_МГТС2
preset_russia
```

</details>

---

## Custom Configurations

Mount the required volumes in `docker-compose.yml` (see above). On first startup, default configs are automatically copied into empty directories.

### sing-box Config

After the first startup, the file will appear at `./configs/sing-box/sing-box.conf`. By default it is a mixed proxy on port `7890` with DoH. Edit the file as needed: you can add any inbound protocols (VMess, VLESS, Trojan, etc.), configure routing, DNS, and more. After editing, restart the container:

```bash
docker compose restart
```

### zapret Strategies

After the first startup, ready-made strategies will appear in `./configs/zapret/`. You can edit existing ones, remove unused ones, and add your own. The strategy filename is the value of the `ZAPRET_STRATEGY` variable.

---

## Scripts

Scripts are designed to work with `docker-compose.yml` in the current directory.

### Installation

```bash
cd /opt/zapret-singbox

curl -fsSL https://raw.githubusercontent.com/dunamis4tw/zapret-singbox/main/switch_strategy.sh -o switch_strategy.sh
curl -fsSL https://raw.githubusercontent.com/dunamis4tw/zapret-singbox/main/test_strategies.sh -o test_strategies.sh
curl -fsSL https://raw.githubusercontent.com/dunamis4tw/zapret-singbox/main/blockcheck.sh      -o blockcheck.sh

chmod +x switch_strategy.sh test_strategies.sh blockcheck.sh
```

Alternatively, clone the repository — see [Build from Source](#build-from-source).

---

### `switch_strategy.sh` — change strategy

Interactive strategy selection from the list. Updates `docker-compose.yml` and restarts the container.

```bash
./switch_strategy.sh
```

<details>
<summary>Example output</summary>

```

📋 Available strategies:

  1) DiscordFix                       19) UltimateFix_ALT_v7              37) general_ALT4
  2) DiscordFix_ALT                   20) UltimateFix_ALT_v8              38) general_ALT5
  3) DiscordFix_ALT2                  21) UltimateFix_ALT_v9              39) general_ALT6
  4) DiscordFix_для_МГТС              22) UltimateFix_Universal           40) general_ALT7
  5) GeneralFix                       23) UltimateFix_Universal_v2        41) general_ALT8
  6) GeneralFix_ALT                   24) UltimateFix_Universal_v3        42) general_ALT9
  7) GeneralFix_ALT3                  25) UltimateFix_для_МГТС            43) general_fake_tls_auto
  8) GeneralFix_ALT4                  26) YoutubeFix_ALT                ▶ 44) general_fake_tls_auto_alt
  9) RussiaFix                        27) discord                         45) general_fake_tls_auto_alt_2
  10) UltimateFix                     28) fix_v1                          46) general_fake_tls_auto_alt_3
  11) UltimateFix_ALT                 29) fix_v2                          47) general_old
  12) UltimateFix_ALT_EXTENDED        30) fix_v3                          48) general_simple_fake
  13) UltimateFix_ALT_v10             31) general                         49) general_simple_fake_alt
  14) UltimateFix_ALT_v2              32) general_ALT                     50) general_simple_fake_alt2
  15) UltimateFix_ALT_v3              33) general_ALT10                   51) general_МГТС
  16) UltimateFix_ALT_v4              34) general_ALT11                   52) general_МГТС2
  17) UltimateFix_ALT_v5              35) general_ALT2                    53) preset_russia
  18) UltimateFix_ALT_v6              36) general_ALT3

▶  — current strategy: general_fake_tls_auto_alt

Enter strategy number [1-53]: 42

⚙️  Selected strategy: general_ALT9
✅ docker-compose.yml updated

🔄 Restarting container...
[+] up 1/1
 ✔ Container zapret-singbox Started                                                                                                                                              1.9s

✅ Container restarted with strategy: general_ALT9

```

</details>

---

### `test_strategies.sh` — test strategies

Sequentially applies selected strategies and checks site availability through the proxy. Results are saved to `./strategy_test_results/`.

```bash
./test_strategies.sh
```

<details>
<summary>Example output</summary>

```

━━━ Step 1: Select strategies ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1) discord                         19) general_ALT8                   37) UltimateFix
  2) DiscordFix                      20) general_ALT9                   38) UltimateFix_ALT
  3) DiscordFix_ALT                  21) general_fake_tls_auto          39) UltimateFix_ALT_EXTENDED
  4) DiscordFix_ALT2                 22) general_fake_tls_auto_alt      40) UltimateFix_ALT_v10
  5) DiscordFix_для_МГТС             23) general_fake_tls_auto_alt_2    41) UltimateFix_ALT_v2
  6) fix_v1                        ▶ 24) general_fake_tls_auto_alt_3    42) UltimateFix_ALT_v3
  7) fix_v2                          25) GeneralFix                     43) UltimateFix_ALT_v4
  8) fix_v3                          26) GeneralFix_ALT                 44) UltimateFix_ALT_v5
  9) general                         27) GeneralFix_ALT3                45) UltimateFix_ALT_v6
  10) general_ALT                    28) GeneralFix_ALT4                46) UltimateFix_ALT_v7
  11) general_ALT10                  29) general_old                    47) UltimateFix_ALT_v8
  12) general_ALT11                  30) general_simple_fake            48) UltimateFix_ALT_v9
  13) general_ALT2                   31) general_simple_fake_alt        49) UltimateFix_Universal
  14) general_ALT3                   32) general_simple_fake_alt2       50) UltimateFix_Universal_v2
  15) general_ALT4                   33) general_МГТС                   51) UltimateFix_Universal_v3
  16) general_ALT5                   34) general_МГТС2                  52) UltimateFix_для_МГТС
  17) general_ALT6                   35) preset_russia                  53) YoutubeFix_ALT
  18) general_ALT7                   36) RussiaFix

  ▶ — current strategy: general_fake_tls_auto_alt_3

Enter strategy numbers [1-53] (ranges: 1,3,10-20 | Enter = all): 9,23-24

  Selected strategies: 3

━━━ Step 2: Select sites ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   1) https://rutracker.org
   2) https://discord.com
   3) https://youtube.com
   4) https://x.com
   5) https://instagram.com
   6) https://t.me
   7) https://store.steampowered.com

Add your own sites? (comma-separated, or Enter to skip): google.com,bbc.com

Enter site numbers [1-9] (ranges: 1,3-5 | Enter = all): 1-3,7-9

  Selected sites: 6
    • https://rutracker.org
    • https://discord.com
    • https://youtube.com
    • https://store.steampowered.com
    • google.com
    • bbc.com

━━━ Starting tests ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Log: ./strategy_test_results/2026-03-21_15-19-14_test.log

Start? [Y/n]: y

[1/3] Strategy: general
────────────────────────────────────────────
  Waiting 4s after restart...
    ✘  rutracker.org              TIMEOUT (>5s)
    ✘  discord.com                TIMEOUT (>5s)
    ✘  youtube.com                TIMEOUT (>5s)
    ✘  store.steampowered.com     TIMEOUT (>5s)
    ✘  google.com                 TIMEOUT (>5s)
    ✘  bbc.com                    TIMEOUT (>5s)
────────────────────────────────────────────

[2/3] Strategy: general_fake_tls_auto_alt_2
────────────────────────────────────────────
  Waiting 4s after restart...
    ✘  rutracker.org              TIMEOUT (>5s)
    ✘  discord.com                TIMEOUT (>5s)
    ✘  youtube.com                TIMEOUT (>5s)
    ✘  store.steampowered.com     TIMEOUT (>5s)
    ✘  google.com                 TIMEOUT (>5s)
    ✘  bbc.com                    TIMEOUT (>5s)
────────────────────────────────────────────

[3/3] Strategy: general_fake_tls_auto_alt_3
────────────────────────────────────────────
  Waiting 4s after restart...
    ✔  rutracker.org              HTTP 200
    ✔  discord.com                HTTP 200
    ✔  youtube.com                HTTP 200
    ✔  store.steampowered.com     HTTP 200
    ✔  google.com                 HTTP 200
    ✔  bbc.com                    HTTP 200
────────────────────────────────────────────

━━━ Done ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Results: ./strategy_test_results/2026-03-21_15-19-14_test.log

  ✔ = HTTP 2xx/3xx   ~ = HTTP 4xx/5xx or TLS   ✘ = timeout / no connection

Restore original strategy (general_fake_tls_auto_alt_3)? [Y/n]: n

```

</details>

---

### `blockcheck.sh` — find strategy for a specific site

Runs the built-in `blockcheck.sh` from zapret inside the container. Determines which bypass method works for a specific domain. Results are saved to `./blockcheck_results/`.

```bash
./blockcheck.sh
```

> The script will stop zapret during the check. Blockcheck prompts for a domain and runs for several minutes. Based on the result, you can write a custom strategy or pick a suitable one from the existing list.

---

## Build from Source

```bash
git clone https://github.com/dunamis4tw/zapret-singbox.git /opt/zapret-singbox
cd /opt/zapret-singbox

docker compose build
docker compose up -d
docker compose logs -f
```

Component versions are set via `ARG` in `Dockerfile`:

```dockerfile
ARG ZAPRET_VERSION=v72.10
ARG SINGBOX_VERSION=1.13.0
```

<details>
<summary>Rebuild with different versions</summary>

```bash
docker compose build \
  --build-arg ZAPRET_VERSION=v72.11 \
  --build-arg SINGBOX_VERSION=1.14.0
```

</details>

---

## Troubleshooting

**1. Proxy unavailable**

```bash
docker compose ps
docker compose logs zapret-singbox
ss -tlnp | grep 7890   # is the port taken by another process?
```

**2. Strategy not found**

The container exits with an error:
```
[entrypoint] Error: strategy 'my_strategy' not found
```
Check the value of `ZAPRET_STRATEGY` — the list of available strategies is printed to the log right after the error. If you are using custom strategies via a volume, make sure the file with the correct name exists in `./configs/zapret/`.

**3. Configs do not appear in mounted directories**

Default configs are copied only if the directory is **empty** at startup. If it already contains files, auto-copy does not trigger. To reset to defaults:

```bash
docker compose down
rm -rf ./configs/sing-box/* ./configs/zapret/*
docker compose up -d
```

**4. sing-box crashes with a config error**

```bash
docker compose logs zapret-singbox
tail -f ./logs/sing-box/sing-box.log   # if volume is mounted
```
Check that `sing-box.conf` is valid JSON without trailing commas.

**5. Container does not work without `privileged: true`**

`privileged: true` is required — zapret uses `iptables` and `NFQUEUE` inside the container. Without this flag the rules will not be applied.

---

## Components Used

| Component | Author | Repository | License |
|---|---|---|---|
| zapret | bol-van | [github.com/bol-van/zapret](https://github.com/bol-van/zapret) | MIT |
| sing-box | SagerNet | [github.com/SagerNet/sing-box](https://github.com/SagerNet/sing-box) | GPL-3.0 |
| zapret.cfgs | Snowy-Fluffy | [github.com/Snowy-Fluffy/zapret.cfgs](https://github.com/Snowy-Fluffy/zapret.cfgs) | — |

---

## License

MIT License. See the [LICENSE](LICENSE) file.

This project is a wrapper around third-party components. Each component is distributed under its own license (see the table above).
