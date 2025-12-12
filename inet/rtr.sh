#!/bin/bash
# Настройка firewalld на маршрутизаторах
cat > /etc/sysctl.conf << 'EOF'
net.ipv4.ip_forward = 1
EOF
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

firewall-cmd --zone=public --add-forward --permanent
firewall-cmd --zone=public --add-masquerade
firewall-cmd --runtime-to-permanent
echo -e "\n=== External zone ==="
firewall-cmd --zone=external --list-all


echo -e "\nComplite"