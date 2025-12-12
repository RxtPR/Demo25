#!/bin/bash
# Настройка DHCP сервера на HQ-RTR (ALT Linux)

# Установка DHCP сервера
apt-get update
apt-get install -y dhcp-server

# Расчет параметров сети 172.16.7.0/28
# Маска: 255.255.255.240
# Сеть: 172.16.7.0/28
# Доступные адреса: 172.16.7.1 - 172.16.7.14 (15 адресов)
# Броадкаст: 172.16.7.15
# Исключаем маршрутизатор (172.16.7.1)
# Пул: с 172.16.7.3 по 172.16.7.14

# Настройка конфигурации DHCP
cat > /etc/dhcp/dhcpd.conf << 'EOF'
# Конфигурация для сети VLAN200 (172.16.7.0/28)
subnet 172.16.7.0 netmask 255.255.255.240 {
    range 172.16.7.3 172.16.7.14;
    option routers 172.16.7.1;
    option domain-name-servers 192.168.100.2;
    option domain-name "au-team.irpo";
    default-lease-time 600;
    max-lease-time 7200;
}
EOF

# Указание интерфейса для прослушивания
echo 'DHCPDARGS=enp0s8.200' > /etc/sysconfig/dhcpd

# Запуск DHCP сервера
systemctl restart dhcpd
systemctl enable dhcpd

echo "DHCP start"
