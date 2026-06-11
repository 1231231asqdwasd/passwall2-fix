#!/bin/sh
# ============================================================
#  pw2-watch — авто-рестарт ядра passwall2 при смене узла в LuCI.
#
#  Зачем: на некоторых роутерах веб-морда passwall2 коммитит выбор
#  узла (Save & Apply), но НЕ перезапускает прокси-ядро — поэтому
#  трафик продолжает идти через старый узел. Этот сторож следит за
#  выбранным узлом и сам рестартит passwall2, когда узел сменился.
#
#  Установка (на роутере, под root):
#    uclient-fetch -O /tmp/a.sh https://raw.githubusercontent.com/1231231asqdwasd/passwall2-fix/main/install-autoswitch.sh
#    sh /tmp/a.sh
# ============================================================
set -e

# --- сам сторож ---
cat > /usr/bin/pw2-watch <<'EOF'
#!/bin/sh
# Рестартит ядро passwall2, когда выбранный узел (uci) перестал
# совпадать с реально запущенным конфигом ядра. Опрос раз в 5 сек.
last=""
while :; do
    en=$(uci -q get passwall2.@global[0].enabled)
    node=$(uci -q get passwall2.@global[0].node)
    if [ "$en" = "1" ] && [ -n "$node" ] && [ "$node" != "$last" ]; then
        if ! ls /tmp/etc/passwall2/global_*_${node}_*.json >/dev/null 2>&1; then
            logger -t pw2-watch "node changed to $node, restarting passwall2"
            /etc/init.d/passwall2 restart
        fi
        last="$node"
    fi
    sleep 5
done
EOF
chmod +x /usr/bin/pw2-watch

# --- procd-сервис ---
cat > /etc/init.d/pw2-watch <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/pw2-watch
    procd_set_param respawn
    procd_close_instance
}
EOF
chmod +x /etc/init.d/pw2-watch

/etc/init.d/pw2-watch enable
/etc/init.d/pw2-watch restart

echo "pw2-watch installed and running."
echo "Now in LuCI: switch Main Node -> Save & Apply -> core restarts within ~5s."
