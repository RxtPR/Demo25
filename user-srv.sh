#!/bin/bash
# Создание пользователя sshuser и настройка SSH (RED OS)

# Создание пользователя sshuser
useradd -u 1010 -m sshuser
echo "sshuser:P@ssw0rd" | chpasswd

# Настройка sudo для sshuser
echo "sshuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sshuser
chmod 440 /etc/sudoers.d/sshuser

# Создание баннера
echo "Authorized access only" > /etc/ssh/banner

# Настройка SSH
sed -i 's/#Port 22/Port 2024/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 2/' /etc/ssh/sshd_config
echo "AllowUsers sshuser" >> /etc/ssh/sshd_config
echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config

# Перезапуск SSH
systemctl restart sshd

# Открытие порта 2024 в фаерволе
firewall-cmd --permanent --add-port=2024/tcp
firewall-cmd --reload