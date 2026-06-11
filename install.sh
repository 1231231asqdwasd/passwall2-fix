#!/bin/sh
# Минимальный установщик: только подложить правильный ключ и поставить
# luci-app-passwall2 на уже настроенных фидах. Запускать под root на роутере.
set -e
wget -O /tmp/ipk.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/ipk.pub \
  || wget -O /tmp/ipk.pub https://downloads.sourceforge.net/project/openwrt-passwall-build/ipk.pub
opkg-key add /tmp/ipk.pub
opkg update
opkg install luci-app-passwall2
/etc/init.d/rpcd restart
echo "Готово. Обнови LuCI (Ctrl+F5)."
