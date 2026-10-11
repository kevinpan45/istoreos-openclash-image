FROM xkand/istoreos:latest

RUN set -eux; \
    mkdir -p /var/lock /var/run /var/state /var/log /tmp/.uci; \
    /bin/board_detect /etc/board.json 2>/dev/null || echo '{}' > /etc/board.json; \
    test -s /etc/board.json

COPY files/preinit-container.conf /lib/preinit/99_zz_container.conf
COPY files/network /etc/config/network

RUN set -eux; \
    for s in hostapd wpa_supplicant dnsmasq odhcpd dropbear dockerd istoreos-dockerd quickstart; do \
        [ ! -x "/etc/init.d/$s" ] || /etc/init.d/"$s" disable || true; \
    done; \
    sed -i -e '/ttyS0/d' -e '/tty1/d' -e '/hvc0/d' /etc/inittab; \
    printf '#!/bin/sh\nexit 0\n' > /usr/libexec/rescan_nic.sh; \
    chmod +x /usr/libexec/rescan_nic.sh

RUN /etc/init.d/uhttpd enable && /etc/init.d/rpcd enable

COPY luci-app-openclash-0.47.156.apk /tmp/openclash.apk
RUN apk add --allow-untrusted /tmp/openclash.apk && rm -f /tmp/openclash.apk

RUN set -eux; \
    for s in dnsmasq odhcpd; do \
        [ ! -x "/etc/init.d/$s" ] || /etc/init.d/"$s" disable || true; \
    done; \
    uci set firewall.@defaults[0].input='ACCEPT'; \
    uci commit firewall; \
    /etc/init.d/firewall enable; \
    uci set openclash.config.lan_interface_name='eth0'; \
    uci commit openclash

COPY OpenClash_0.47.156+x86_64_core.run /tmp/openclash-core.run
RUN set -eux; \
    sh /tmp/openclash-core.run --noexec --target /tmp/oc-core; \
    mkdir -p /etc/openclash/core; \
    cp /tmp/oc-core/clash_meta /etc/openclash/core/clash_meta; \
    chown root:root /etc/openclash/core/clash_meta; \
    chmod +x /etc/openclash/core/clash_meta; \
    rm -rf /tmp/oc-core /tmp/openclash-core.run; \
    /etc/openclash/core/clash_meta -v

COPY files/rc.local /etc/rc.local
RUN chmod +x /etc/rc.local

EXPOSE 80 7890 7893
CMD ["/sbin/init"]
