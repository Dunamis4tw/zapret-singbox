FROM debian:bookworm-slim

ARG ZAPRET_VERSION=v72.10
ARG SINGBOX_VERSION=1.13.0

# ── 1. Устанавливаем зависимости ─────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    iptables \
    ipset \
    git \
    curl \
    bash \
    ca-certificates \
    procps \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# iptables-legacy надёжнее чем iptables-nft
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# ── 2. Устанавливаем sing-box ────────────────────────────────────────────────────────────────────
RUN mkdir -p /opt/sing-box/configs /opt/sing-box/logs \
    && curl -fsSL \
       "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz" \
       | tar xz -C /opt/sing-box --strip-components=1

# Дефолтный конфиг — будет перекрыт volume при запуске
COPY configs/sing-box/sing-box.conf /opt/sing-box/configs/sing-box.conf

# ── 3. Устанавливаем zapret ──────────────────────────────────────────────────────────────────────
RUN mkdir -p /opt/zapret \
    && curl -fsSL \
       "https://github.com/bol-van/zapret/releases/download/${ZAPRET_VERSION}/zapret-${ZAPRET_VERSION}.tar.gz" \
       | tar xz -C /opt/zapret --strip-components=1

# Запускаем установщик zapret с автоподтверждением
RUN cd /opt/zapret \
    && sed -i '238s/ask_yes_no N/ask_yes_no Y/' /opt/zapret/common/installer.sh \
    && yes "" | bash ./install_easy.sh || true \
    && sed -i '238s/ask_yes_no Y/ask_yes_no N/' /opt/zapret/common/installer.sh

# ── 4. Качаем стратегии и списки ─────────────────────────────────────────────────────────────────
RUN git clone https://github.com/Snowy-Fluffy/zapret.cfgs /opt/zapret/zapret.cfgs \
    && cp -r /opt/zapret/zapret.cfgs/bin/* /opt/zapret/files/fake \
    && cp /opt/zapret/zapret.cfgs/lists/list-basic.txt /opt/zapret/ipset/zapret-hosts-user.txt \
    && cp /opt/zapret/zapret.cfgs/lists/ipset-discord.txt /opt/zapret/ipset/ipset-discord.txt \
    && touch /opt/zapret/ipset/ipset-game.txt

# Бэкапим стратегии до того как volume их перекроет
RUN cp -r /opt/zapret/zapret.cfgs/configurations \
          /opt/zapret/zapret.cfgs/configurations.bak

# ── Entrypoint ───────────────────────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7890

ENTRYPOINT ["/entrypoint.sh"]
