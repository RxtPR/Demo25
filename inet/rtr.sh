#!/bin/bash
# Настройка firewalld на маршрутизаторах

# Установка firewalld (если не установлен)
apt-get update
apt-get install -y firewalld

# Запуск и включение
systemctl start firewalld
systemctl enable firewalld

# Добавление туннеля в trusted зону
firewall-cmd --zone=trusted --add-source=10.10.10.0/30 --permanent

# Добавление сервиса gre в external зону
firewall-cmd --zone=external --add-service=gre --permanent

# Перезагрузка firewalld
firewall-cmd --reload

# Вывод информации о настройках
echo "=== Trusted zone ==="
firewall-cmd --zone=trusted --list-all

echo -e "\n=== External zone ==="
firewall-cmd --zone=external --list-all

echo -e "\nНастройка firewalld на маршрутизаторе завершена"