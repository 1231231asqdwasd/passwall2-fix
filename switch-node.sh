#!/bin/sh
# ============================================================
#  Переключатель рабочего узла passwall2 из консоли.
#  Зачем: веб-морда LuCI passwall2 часто НЕ коммитит выбор узла
#  (жмёшь Save & Apply, подсветка меняется, а узел остаётся старый,
#  ядро не перезапускается). Этот скрипт пишет узел через uci,
#  коммитит и перезапускает passwall2 — надёжно.
#
#  Использование:
#    sh switch-node.sh         — показать список узлов
#    sh switch-node.sh 2       — сделать рабочим узел №2 из списка
# ============================================================

G='\033[0;32m'; Y='\033[1;33m'; N='\033[0m'

cur=$(uci get passwall2.@global[0].node 2>/dev/null)

# только узлы с адресом (отсекаем шаблонные examplenode/rulenode)
nodes=""
for id in $(uci show passwall2 | sed -n 's/^passwall2\.\([^.]*\)=nodes$/\1/p'); do
  [ -n "$(uci get passwall2.$id.address 2>/dev/null)" ] && nodes="$nodes $id"
done

echo "Узлы passwall2:"
i=0
for id in $nodes; do
  i=$((i+1))
  mark=""; [ "$id" = "$cur" ] && mark="${G} <= текущий${N}"
  printf "  ${Y}%2d${N}) %-12s %s [%s]%b\n" "$i" "$id" \
    "$(uci get passwall2.$id.remarks 2>/dev/null)" \
    "$(uci get passwall2.$id.address 2>/dev/null)" "$mark"
done

# без аргумента — просто список
if [ -z "$1" ]; then
  echo "Переключить: sh $0 <номер>"
  exit 0
fi

# выбрать N-й id
sel=""; i=0
for id in $nodes; do
  i=$((i+1))
  [ "$i" = "$1" ] && sel="$id"
done
if [ -z "$sel" ]; then
  echo "${Y}Нет узла №$1${N}"
  exit 1
fi

echo "Переключаю на: $sel ($(uci get passwall2.$sel.remarks 2>/dev/null))..."
uci set passwall2.@global[0].node="$sel"
uci set passwall2.@global[0].enabled='1'
uci commit passwall2
/etc/init.d/passwall2 restart
sleep 6

# проверка
echo "Записано: $(uci get passwall2.@global[0].node)"
if ps w | grep -E 'sing-box|hysteria|xray' | grep -v grep >/dev/null; then
  echo "${G}Ядро запущено. OK.${N}"
else
  echo "${Y}Ядро НЕ запущено — смотри tail -30 /tmp/log/passwall2.log${N}"
fi
