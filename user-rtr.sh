#!/bin/bash
# Создание пользователя net_admin (ALT Linux)

# Создание пользователя net_admin
useradd -m net_admin
echo "net_admin:P@\$\$word" | chpasswd

# Настройка sudo для net_admin
usermod -aG wheel net_admin
echo "net_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers