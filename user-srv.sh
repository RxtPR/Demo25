#!/bin/bash
# Создание пользователя sshuser и настройка SSH (RED OS)

# Создание пользователя sshuser
useradd -u 1010 -m sshuser
echo "sshuser:P@ssw0rd" | chpasswd

# Настройка sudo для sshuser
usermod -aG wheel sshuser
echo "sshuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Создание баннера
echo "Authorized access only" > /etc/ssh/banner

# Настройка SSH
sed -i 's/#Port 22/Port 2024/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 2/' /etc/ssh/sshd_config
echo "AllowUsers sshuser" >> /etc/ssh/sshd_config
echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config

[ "$EUID" -ne 0 ] && echo "Ошибка: Запустите скрипт от root: sudo $0" && exit 1

echo "Текущий статус SELinux:"
sestatus 2>/dev/null || echo "Команда 'sestatus' не найдена. Возможно, SELinux не установлен."

# Резервное копирование и изменение конфигурации
CONFIG_FILE="/etc/selinux/config"
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' "$CONFIG_FILE"
    echo "✓ Файл $CONFIG_FILE изменен на SELINUX=disabled"
    echo "  Создана резервная копия: $CONFIG_FILE.bak"
else
    echo "Файл конфигурации $CONFIG_FILE не найден."
fi

echo ""
echo "Для ПРИМЕНЕНИЯ ИЗМЕНЕНИЙ необходима ПЕРЕЗАГРУЗКА системы."
# Перезапуск SSH
systemctl restart sshd

# Открытие порта 2024 в фаерволе
firewall-cmd --permanent --add-port=2024/tcp
firewall-cmd --reload