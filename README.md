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

## Файлы

- `passwall2x.sh` — полный установщик (фиды + ключ + пакеты).
- `install.sh` — минимальный фикс ключа + установка пакета.
- `ipk.pub` — публичный ключ подписи (резерв, если `wget` не возьмёт).
