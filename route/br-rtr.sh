#!/bin/bash
# Добавление статических маршрутов на BR-RTR

# Маршрут по умолчанию через ISP
ip route add default via 172.16.5.1 dev ens18

# Маршруты до сетей HQ-RTR через GRE тунель
ip route add 172.16.7.0/28 via 10.10.10.2 dev gre0
ip route add 192.168.100.0/26 via 10.10.10.2 dev gre0
ip route add 172.16.8.0/29 via 10.10.10.2 dev gre0

# Включение форвардинга
echo 1 > /proc/sys/net/ipv4/ip_forward

# Сохранение маршрутов
cat > /etc/sysconfig/network-scripts/route-ens18 << 'EOF'
default via 172.16.5.1
EOF

# Для GRE тунеля
cat > /etc/sysconfig/network-scripts/route-gre0 << 'EOF'
172.16.7.0/28 via 10.10.10.2
192.168.100.0/26 via 10.10.10.2
172.16.8.0/29 via 10.10.10.2
EOF

echo "Маршруты на BR-RTR добавлены"