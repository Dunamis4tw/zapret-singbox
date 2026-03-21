FROM debian:bookworm-slim

ARG ZAPRET_VERSION=v72.10
ARG SINGBOX_VERSION=1.13.0

# ---------------------------------------------------------------------------
# 1. Зависимости
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    iptables \
    ipset \
    git \
    curl \
    bash \
    ca-certificates \
    procps \
    dnsutils \
    locales \
    && echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8

# iptables-legacy стабильнее работает в привилегированных контейнерах
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# ---------------------------------------------------------------------------
# 2. sing-box
# ---------------------------------------------------------------------------
RUN mkdir -p /opt/sing-box/configs /opt/sing-box/logs \
    && curl -fsSL \
       "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz" \
       | tar xz -C /opt/sing-box --strip-components=1

# Дефолтный конфиг копируется в образ.
# Если volume не подключён — используется он.
# Если volume подключён и пуст — entrypoint восстановит его из бэкапа.
COPY configs/sing-box/sing-box.conf /opt/sing-box/configs/sing-box.conf

# Бэкап дефолтного конфига — не перекрывается volume
RUN cp -r /opt/sing-box/configs /opt/sing-box/configs.bak

# ---------------------------------------------------------------------------
# 3. zapret
# ---------------------------------------------------------------------------
RUN mkdir -p /opt/zapret \
    && curl -fsSL \
       "https://github.com/bol-van/zapret/releases/download/${ZAPRET_VERSION}/zapret-${ZAPRET_VERSION}.tar.gz" \
       | tar xz -C /opt/zapret --strip-components=1

RUN cd /opt/zapret \
    && sed -i '238s/ask_yes_no N/ask_yes_no Y/' /opt/zapret/common/installer.sh \
    && yes "" | bash ./install_easy.sh || true \
    && sed -i '238s/ask_yes_no Y/ask_yes_no N/' /opt/zapret/common/installer.sh

# ---------------------------------------------------------------------------
# 4. Стратегии и списки zapret
# ---------------------------------------------------------------------------
RUN git clone https://github.com/Snowy-Fluffy/zapret.cfgs /opt/zapret/zapret.cfgs \
    && cp -r /opt/zapret/zapret.cfgs/bin/* /opt/zapret/files/fake \
    && cp /opt/zapret/zapret.cfgs/lists/list-basic.txt /opt/zapret/ipset/zapret-hosts-user.txt \
    && cp /opt/zapret/zapret.cfgs/lists/ipset-discord.txt /opt/zapret/ipset/ipset-discord.txt \
    && touch /opt/zapret/ipset/ipset-game.txt

# Бэкап стратегий — не перекрывается volume
RUN cp -r /opt/zapret/zapret.cfgs/configurations \
          /opt/zapret/zapret.cfgs/configurations.bak

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7890

ENTRYPOINT ["/entrypoint.sh"]