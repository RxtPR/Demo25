#!/bin/bash
# Добавление статических маршрутов на ISP

# Маршруты для сетей за HQ-RTR (через enp0s8, следующий хоп 172.16.4.2)
ip route add 172.16.7.0/28 via 172.16.4.2 dev enp0s8
ip route add 192.168.100.0/26 via 172.16.4.2 dev enp0s8
ip route add 172.16.8.0/29 via 172.16.4.2 dev enp0s8
ip route add 10.10.10.0/30 via 172.16.4.2 dev enp0s8

# Маршрут для сети за BR-RTR (через enp0s9, следующий хоп 172.16.5.2)
ip route add 192.168.200.0/27 via 172.16.5.2 dev enp0s9

# Сохранение маршрутов (для ALT Linux)
# Создаем файлы маршрутов для интерфейсов
cat > /etc/sysconfig/network-scripts/route-enp0s8 << 'EOF'
172.16.7.0/28 via 172.16.4.2
192.168.100.0/26 via 172.16.4.2
172.16.8.0/29 via 172.16.4.2
10.10.10.0/30 via 172.16.4.2
EOF

cat > /etc/sysconfig/network-scripts/route-enp0s9 << 'EOF'
192.168.200.0/27 via 172.16.5.2
EOF

echo "Маршруты добавлены и сохранены"