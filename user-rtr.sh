#!/bin/bash
# Создание пользователя net_admin (ALT Linux)

# Создание пользователя net_admin
useradd -m net_admin
echo "net_admin:P@\$\$word" | chpasswd

# Настройка sudo для net_admin
echo "net_admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/net_admin
chmod 440 /etc/sudoers.d/net_admin