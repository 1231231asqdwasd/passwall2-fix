# Passwall2 installer (OpenWrt 24.10) — fixed fork

Форк [amirhosseinchoghaei/Passwall](https://github.com/amirhosseinchoghaei/Passwall),
который чинит установку **luci-app-passwall2** и убирает региональный/мутный мусор.

## Зачем

Оригинальный скрипт качает ключ подписи фидов по адресу
`.../openwrt-passwall-build/passwall.pub`, который теперь отдаёт **404**.
Без ключа `opkg` не проходит проверку подписи, удаляет скачанные списки
пакетов (`Signature check failed` → `Remove wrong Signature file`) и падает с

```
Unknown package 'luci-app-passwall2'.
* opkg_install_cmd: Cannot install package luci-app-passwall2.
```

Ключ переименовали в **`ipk.pub`** — этот форк использует правильный адрес.

## Что изменено

- `passwall.pub` → `ipk.pub` (главный фикс).
- Убрано: таймзона Тегеран, hostname-ребренд, скачивание `iam.zip` с
  `amir3.space` в корень ФС, ir-specific DNS rebind / `geoip:ir`, рекламный баннер.
- Добавлены проверки root, понятные сообщения, fallback-зеркало ключа.

## Установка (на роутере, под root)

```sh
wget -O passwall2x.sh https://raw.githubusercontent.com/1231231asqdwasd/passwall2-fix/main/passwall2x.sh
sh passwall2x.sh
```

После — обнови LuCI (Ctrl+F5), меню **Сервисы → PassWall 2**.

### Если passwall2 уже стоял, нужно только починить ключ

```sh
sh install.sh
```

## Запасной вариант (ключ не подходит)

Поставить без проверки подписи (фиды доверенные):

```sh
sed -i 's/^option check_signature/# option check_signature/' /etc/opkg.conf
opkg update && opkg install luci-app-passwall2
sed -i 's/^# option check_signature/option check_signature/' /etc/opkg.conf
```

## Решение проблем

### `Unknown package 'luci-app-passwall2'` / `Signature check failed`
Старый ключ подписи `passwall.pub` отдаёт 404 → opkg удаляет списки пакетов.
Лечится правильным ключом (это и есть главный фикс форка):
```sh
wget -O /tmp/ipk.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/ipk.pub
opkg-key add /tmp/ipk.pub
opkg update && opkg install luci-app-passwall2
```

### «Core NOT RUNNING», в логе `missing basic dependency kmod-nft-socket / kmod-nft-tproxy`
Самая частая засада. Пакеты `kmod-nft-socket`/`kmod-nft-tproxy` установлены, но
**не загружены в ядро**, поэтому passwall2 не может собрать nftables-правила для
tproxy и не доходит до запуска ядра (`bin/` пустой, конфиг не генерится). Лечится:
```sh
modprobe nft_socket
modprobe nft_tproxy
lsmod | grep -E 'nft_socket|nft_tproxy'          # должны быть видны обе
# закрепить автозагрузку, чтобы не пропало после reboot:
printf 'nft_socket\nnft_tproxy\n' > /etc/modules.d/30-passwall2-tproxy
/etc/init.d/passwall2 restart
```
> Свежий `passwall2x.sh` делает это автоматически — баг актуален для старых установок.

### Ядро не стартует для Hysteria2-узла
Hysteria2 умеет **sing-box** (или бинарь `hysteria`), а **не xray**. Если стоит
только `xray-core` — поставь `opkg install sing-box`. Проверка конфига:
`sing-box check -c <путь к global_*.json из /tmp/etc/passwall2/>`.

### Узел не запускается после обновления подписки
Иногда сервис остаётся в стопе (в логе хвост — `Clearing and closing... Running
complete!` без последующего старта). Просто перезапусти: `/etc/init.d/passwall2 restart`.

### Русификатор LuCI для passwall2
Положи `.lmo` в каталог i18n (создай его, если нет), качай через `uclient-fetch`
(busybox `wget` не тянет редирект GitHub):
```sh
mkdir -p /usr/lib/lua/luci/i18n
uclient-fetch --no-check-certificate -O /usr/lib/lua/luci/i18n/passwall2.ru.lmo \
  "https://github.com/gooog1111/luci-i18n-openwrt-passwall2-ru/releases/latest/download/passwall2.ru.lmo"
```
И поставь базовый русский: `opkg install luci-i18n-base-ru`, затем выбери язык в
**System → System → Language**.

## Файлы

- `passwall2x.sh` — полный установщик (фиды + ключ + пакеты + tproxy-модули).
- `install.sh` — минимальный фикс ключа + установка пакета.
- `ipk.pub` — публичный ключ подписи (резерв, если `wget` не возьмёт).
