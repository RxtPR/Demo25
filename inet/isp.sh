#!/bin/bash
# Настройка firewalld на ISP

cat > /etc/sysctl.conf << 'EOF'
net.ipv4.ip_forward = 1
EOF

# Установка firewalld (если не установлен)
apt-get update
apt-get install -y firewalld

# Запуск и включение
systemctl start firewalld
systemctl enable firewalld

# Проверка статуса
firewall-cmd --state
firewall-cmd --list-all-zones

# Добавление интерфейсов в зоны
firewall-cmd --zone=external --change-interface=enp0s3 --permanent
firewall-cmd --zone=internal --change-interface=enp0s8 --permanent
firewall-cmd --zone=internal --change-interface=enp0s9 --permanent

# Добавление маскарада и форварда на зону external
firewall-cmd --zone=external --add-masquerade --permanent
firewall-cmd --zone=external --add-forward --permanent

# Добавление источников в зону internal
firewall-cmd --zone=internal --add-source=172.16.4.0/28 --permanent
firewall-cmd --zone=internal --add-source=172.16.5.0/28 --permanent

# Добавление форварда в зону internal
firewall-cmd --zone=internal --add-forward --permanent

# Перезагрузка firewalld
firewall-cmd --reload

# Создание новой политики
firewall-cmd --new-policy IntToExt --permanent
firewall-cmd --policy IntToExt --add-ingress-zone internal --permanent
firewall-cmd --policy IntToExt --add-egress-zone external --permanent
firewall-cmd --policy IntToExt --set-target ACCEPT --permanent

firewall-cmd --permanent --zone=internal --set-target=ACCEPT
firewall-cmd --permanent --zone=internal --add-port=89/udp
# Финальная перезагрузка
firewall-cmd --reload

# Вывод информации о настройках
echo "=== External zone ==="
firewall-cmd --zone=external --list-all

echo -e "\n=== Internal zone ==="
firewall-cmd --zone=internal --list-all

echo -e "\n=== IntToExt policy ==="
firewall-cmd --info-policy=IntToExt

echo -e "\nComplite"