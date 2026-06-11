#!/bin/sh
# ============================================================
#  Passwall2 installer for OpenWrt 24.10 (opkg)
#  Форк amirhosseinchoghaei/Passwall.
#
#  Что исправлено:
#   * Ключ подписи: passwall.pub -> ipk.pub (старый URL отдаёт 404,
#     из-за чего фиды не проходят проверку подписи и пакет
#     "luci-app-passwall2" не находится).
#   * Убрано региональное/мутное: таймзона Тегеран, hostname-ребренд,
#     скачивание iam.zip с amir3.space в корень, ir-specific DNS/гео,
#     рекламный баннер.
# ============================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

[ "$(id -u)" = "0" ] || { echo -e "${RED}Запускать под root.${NC}"; exit 1; }

echo -e "${GREEN} Обновляю списки пакетов... ${NC}"
opkg update

# --- Проверка на SNAPSHOT (там opkg нет, нужен apk) ---
if grep -q SNAPSHOT /etc/openwrt_release; then
  echo -e "${RED} Обнаружен SNAPSHOT. Этот скрипт для стабильных релизов (24.10) с opkg.${NC}"
  echo -e "${YELLOW} Для SNAPSHOT ставь через apk: см. github.com/Openwrt-Passwall/openwrt-passwall2${NC}"
  exit 1
fi

# --- Правильный ключ подписи фидов ---
echo -e "${GREEN} Добавляю ключ подписи (ipk.pub)... ${NC}"
wget -O /tmp/ipk.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/ipk.pub \
  || wget -O /tmp/ipk.pub https://downloads.sourceforge.net/project/openwrt-passwall-build/ipk.pub
opkg-key add /tmp/ipk.pub

# --- Фиды passwall ---
echo -e "${GREEN} Прописываю фиды passwall... ${NC}"
> /etc/opkg/customfeeds.conf
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
for feed in passwall_luci passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

opkg update

# --- Зависимости + сам пакет ---
echo -e "${GREEN} Ставлю dnsmasq-full и зависимости... ${NC}"
opkg remove dnsmasq 2>/dev/null
opkg install dnsmasq-full
opkg install wget-ssl
opkg install unzip
opkg install luci-app-passwall2
opkg install kmod-nft-socket
opkg install kmod-nft-tproxy
opkg install ca-bundle
opkg install kmod-inet-diag
opkg install kmod-netlink-diag
opkg install kmod-tun
opkg install ipset

# --- tproxy-модули ядра: загрузить СЕЙЧАС и закрепить автозагрузку ---
# Без этого passwall2 ругается "missing basic dependency kmod-nft-socket/tproxy"
# и ядро не стартует ("Core NOT RUNNING"), хотя пакеты kmod установлены.
echo -e "${GREEN} Загружаю tproxy-модули ядра... ${NC}"
modprobe nft_socket 2>/dev/null
modprobe nft_tproxy 2>/dev/null
printf 'nft_socket\nnft_tproxy\n' > /etc/modules.d/30-passwall2-tproxy

# --- Ядро прокси ---
echo -e "${GREEN} Ставлю прокси-ядра (sing-box для Hysteria2/vless, xray)... ${NC}"
opkg install sing-box || echo -e "${YELLOW} sing-box не установился (нужен для Hysteria2!) ${NC}"
opkg install xray-core

# --- Проверка результата ---
if [ -f /etc/init.d/passwall2 ]; then
  echo -e "${GREEN} Passwall2 установлен успешно! ${NC}"
else
  echo -e "${RED} Не удалось установить luci-app-passwall2. Смотри вывод opkg выше. ${NC}"
  exit 1
fi

if [ -f /usr/lib/opkg/info/dnsmasq-full.control ]; then
  echo -e "${GREEN} dnsmasq-full: OK ${NC}"
else
  echo -e "${YELLOW} dnsmasq-full не установлен — проверь вручную. ${NC}"
fi

if [ -x /usr/bin/xray ]; then
  echo -e "${GREEN} xray: OK ${NC}"
else
  echo -e "${YELLOW} xray не установлен — узлы vless/xray работать не будут. ${NC}"
fi

/etc/init.d/rpcd restart
echo -e "${GREEN} Готово. Обнови LuCI (Ctrl+F5) -> меню 'Сервисы' -> PassWall 2. ${NC}"
