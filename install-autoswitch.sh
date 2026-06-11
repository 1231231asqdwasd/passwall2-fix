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
# Рестартит ядро passwall2 при ЛЮБОМ изменении /etc/config/passwall2
# (смена узла, правка скорости/портов и т.п.). LuCI коммитит конфиг, но
# не рестартит ядро — этот сторож закрывает дыру.
#
# Логика: считаем md5 конфига. Если изменился — ждём 3с (даём морде
# дописать), и если хэш устаканился — рестартим. После рестарта берём
# хэш заново как базовый (passwall2 мог обновить timestamp) — без петли.
prev=""
while :; do
    if [ "$(uci -q get passwall2.@global[0].enabled)" = "1" ]; then
        h=$(md5sum /etc/config/passwall2 2>/dev/null | cut -d' ' -f1)
        if [ -n "$prev" ] && [ -n "$h" ] && [ "$h" != "$prev" ]; then
            sleep 3
            h2=$(md5sum /etc/config/passwall2 2>/dev/null | cut -d' ' -f1)
            if [ "$h2" = "$h" ]; then
                logger -t pw2-watch "passwall2 config changed, restarting core"
                /etc/init.d/passwall2 restart
                sleep 8
                h=$(md5sum /etc/config/passwall2 2>/dev/null | cut -d' ' -f1)
            fi
        fi
        prev="$h"
    fi
    sleep 4
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
