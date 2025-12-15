#!/bin/bash

# Проверяем, что мы на нужной машине
CURRENT_HOST=$(hostname)
if [[ "$CURRENT_HOST" != "hq-rtr.au-team.irpo" && "$CURRENT_HOST" != "br-rtr.au-team.irpo" ]]; then
    echo "Ошибка: скрипт должен выполняться на hq-rtr.au-team.irpo или br-rtr.au-team.irpo, а не на $CURRENT_HOST"
    echo "Посылаю нахуй..."
    exit 1
fi

set -e  # Прерывать выполнение при любой ошибке

echo "=== Начинаю выполнение скриптов на машине $CURRENT_HOST ==="
echo ""

# --- Функции ---
configure_nm_connection() {
    local conn_name=$1
    local iface=$2
    local ip=$3
    local gateway=$4
    local dns=$5

    nmcli connection delete "$conn_name" 2>/dev/null || true
    
    if [[ "$ip" == "DHCP" ]]; then
        nmcli connection add type ethernet con-name "$conn_name" ifname "$iface" ipv4.method auto
    else
        nmcli connection add type ethernet con-name "$conn_name" ifname "$iface" ipv4.method manual ipv4.addresses "$ip"
        
        if [[ -n "$gateway" && "$gateway" != "none" ]]; then
            nmcli connection modify "$conn_name" ipv4.gateway "$gateway"
        fi
    fi
    
    if [[ -n "$dns" ]]; then
        nmcli connection modify "$conn_name" ipv4.dns "$dns"
    fi
    
    nmcli connection up "$conn_name"
}

configure_vlan() {
    local conn_name=$1
    local parent_iface=$2
    local vlan_id=$3
    local ip=$4
    local gateway=$5
    local dns=$6

    nmcli connection delete "$conn_name" 2>/dev/null || true
    
    nmcli connection add type vlan con-name "$conn_name" ifname "${parent_iface}.${vlan_id}" \
        dev "$parent_iface" id "$vlan_id" ipv4.method manual ipv4.addresses "$ip"
    
    if [[ -n "$gateway" && "$gateway" != "none" ]]; then
        nmcli connection modify "$conn_name" ipv4.gateway "$gateway"
    fi
    
    if [[ -n "$dns" ]]; then
        nmcli connection modify "$conn_name" ipv4.dns "$dns"
    fi
    
    nmcli connection up "$conn_name"
}

configure_gre() {
    local conn_name=$1
    local local_ip=$2
    local remote_ip=$3
    local tunnel_ip=$4
    local dns=$5

    nmcli connection delete "$conn_name" 2>/dev/null || true
    
    nmcli connection add type ip-tunnel con-name "$conn_name" \
        ifname "$conn_name" mode gre \
        local "$local_ip" remote "$remote_ip" \
        ipv4.method manual ipv4.addresses "$tunnel_ip"
    
    if [[ -n "$dns" ]]; then
        nmcli connection modify "$conn_name" ipv4.dns "$dns"
    fi
    
    nmcli connection up "$conn_name"
}

# --- 1. Выполняем ip.sh (адаптированный) ---
echo "=== 1. Запуск ip.sh ==="
DNS_SERVER="8.8.8.8"

case $CURRENT_HOST in
    "hq-rtr.au-team.irpo")
        echo "Настраиваю HQ-RTR..."
        
        # Основной интерфейс enp0s3
        configure_nm_connection "enp0s3-main" "enp0s3" "172.16.4.2/28" "172.16.4.1" "$DNS_SERVER"
        
        # Интерфейс enp0s8 - настраиваем вручную без IP (только для VLAN)
        echo "Настройка enp0s8 для VLAN..."
        
        # Удаляем все соединения для enp0s8
        for conn in $(nmcli -t -f NAME connection show | grep enp0s8); do
            nmcli connection delete "$conn" 2>/dev/null || true
        done
        
        # Отключаем интерфейс
        nmcli device disconnect enp0s8 2>/dev/null || true
        
        # Создаем соединение для enp0s8 без IP-адреса
        nmcli connection add type ethernet con-name "enp0s8-vlan-trunk" ifname enp0s8 \
            ipv4.method disabled ipv6.method ignore
        
        # Включаем интерфейс
        nmcli connection up "enp0s8-vlan-trunk"
        
        # Ждем активации интерфейса
        sleep 2
        
        # VLAN интерфейсы
        echo "Настройка VLAN интерфейсов..."
        configure_vlan "enp0s8-vlan100" "enp0s8" "100" "192.168.100.1/26" "none" "$DNS_SERVER"
        configure_vlan "enp0s8-vlan200" "enp0s8" "200" "172.16.7.1/28" "none" "$DNS_SERVER"
        configure_vlan "enp0s8-vlan999" "enp0s8" "999" "172.16.8.1/29" "none" "$DNS_SERVER"
        
        # GRE туннель
        echo "Настройка GRE туннеля..."
        configure_gre "gre-tunnel" "172.16.4.2" "172.16.5.2" "10.10.10.2/30" "$DNS_SERVER"
        
        # Включаем маршрутизацию
        sysctl -w net.ipv4.ip_forward=1
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        
        # Настройка правил маршрутизации
        echo "Настройка правил маршрутизации..."
        iptables -t nat -A POSTROUTING -s 192.168.100.0/26 -o enp0s3 -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 172.16.7.0/28 -o enp0s3 -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 172.16.8.0/29 -o enp0s3 -j MASQUERADE
        ;;
        
    "br-rtr.au-team.irpo")
        echo "Настраиваю BR-RTR..."
        
        # Основной интерфейс enp0s3
        configure_nm_connection "enp0s3-main" "enp0s3" "172.16.5.2/28" "172.16.5.1" "$DNS_SERVER"
        
        # Интерфейс enp0s8
        configure_nm_connection "enp0s8-local" "enp0s8" "192.168.200.1/27" "none" "$DNS_SERVER"
        
        # GRE туннель
        configure_gre "gre-tunnel" "172.16.5.2" "172.16.4.2" "10.10.10.1/30" "$DNS_SERVER"
        
        # Включаем маршрутизацию
        sysctl -w net.ipv4.ip_forward=1
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        
        # Настройка правил маршрутизации
        echo "Настройка правил маршрутизации..."
        iptables -t nat -A POSTROUTING -s 192.168.200.0/27 -o enp0s3 -j MASQUERADE
        ;;
esac

echo "Текущие подключения:"
nmcli connection show --active

echo ""
echo "Текущие IP-адреса:"
ip -4 addr show

echo ""
echo "Таблица маршрутизации:"
ip route show

echo ""
echo "✅ ip.sh выполнен успешно"
echo ""

# --- 2. Выполняем inet-rtr.sh ---
echo "=== 2. Запуск inet-rtr.sh ==="
echo "Настройка firewalld на маршрутизаторах..."

# Убедимся, что маршрутизация включена
cat > /etc/sysctl.conf << 'EOF'
net.ipv4.ip_forward = 1
EOF

# Проверяем наличие firewalld
if ! command -v firewall-cmd &> /dev/null; then
    echo "Установка firewalld..."
    apt-get update
    apt-get install -y firewalld
fi

# Запуск и включение
systemctl start firewalld
systemctl enable firewalld

# Добавление туннеля в trusted зону
firewall-cmd --zone=trusted --add-source=10.10.10.0/30 --permanent

# Добавление сервиса gre в external зону
firewall-cmd --zone=external --add-service=gre --permanent

# Перезагрузка firewalld
firewall-cmd --reload

# Настройка для разных хостов
case $CURRENT_HOST in
    "hq-rtr.au-team.irpo")
        # Добавляем интерфейсы в соответствующие зоны
        firewall-cmd --zone=external --change-interface=enp0s3 --permanent
        firewall-cmd --zone=internal --change-interface=enp0s8.100 --permanent
        firewall-cmd --zone=internal --change-interface=enp0s8.200 --permanent
        firewall-cmd --zone=internal --change-interface=enp0s8.999 --permanent
        firewall-cmd --zone=trusted --change-interface=gre-tunnel --permanent
        ;;
        
    "br-rtr.au-team.irpo")
        firewall-cmd --zone=external --change-interface=enp0s3 --permanent
        firewall-cmd --zone=internal --change-interface=enp0s8 --permanent
        firewall-cmd --zone=trusted --change-interface=gre-tunnel --permanent
        ;;
esac

# Включаем маскарадинг и форвардинг
firewall-cmd --zone=external --add-masquerade --permanent
firewall-cmd --zone=external --add-forward --permanent
firewall-cmd --zone=public --add-forward --permanent
firewall-cmd --zone=public --add-masquerade --permanent
firewall-cmd --runtime-to-permanent

# Перезагружаем firewalld
firewall-cmd --reload

# Вывод информации о настройках
echo "=== Trusted zone ==="
firewall-cmd --zone=trusted --list-all

echo -e "\n=== External zone ==="
firewall-cmd --zone=external --list-all

echo ""
echo "✅ inet-rtr.sh выполнен успешно"
echo ""

# --- 3. Выполняем dhcp (ТОЛЬКО на HQ) ---
if [[ "$CURRENT_HOST" == "hq-rtr.au-team.irpo" ]]; then
    echo "=== 3. Запуск dhcp (только для HQ) ==="
    echo "Настройка DHCP сервера на HQ-RTR..."
    
    # Проверяем наличие dhcp-server
    if ! dpkg -l | grep -q dhcp-server; then
        echo "Установка DHCP сервера..."
        apt-get update
        apt-get install -y dhcp-server
    fi
    
    # Расчет параметров сети 172.16.7.0/28
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
    
    echo "DHCP сервер запущен и добавлен в автозагрузку"
    
    echo ""
    echo "✅ dhcp выполнен успешно"
else
    echo "=== 3. Пропускаем dhcp (только для HQ) ==="
    echo "Текущий хост: $CURRENT_HOST - DHCP не требуется"
fi
echo ""

# --- 4. Выполняем user-rtr.sh ---
echo "=== 4. Запуск user-rtr.sh ==="
echo "Создание пользователя net_admin..."

# Проверяем, существует ли пользователь
if id "net_admin" &>/dev/null; then
    echo "Пользователь net_admin уже существует, обновляю пароль..."
    echo "net_admin:P@\$\$word" | chpasswd
else
    # Создание пользователя net_admin
    useradd -m net_admin
    echo "net_admin:P@\$\$word" | chpasswd
fi

# Настройка sudo для net_admin
if ! grep -q "net_admin ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
    usermod -aG wheel net_admin
    echo "net_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "Права sudo добавлены для net_admin"
else
    echo "Права sudo уже настроены для net_admin"
fi

echo ""
echo "✅ user-rtr.sh выполнен успешно"
echo ""

# --- Финальный отчет ---
echo "=== ВСЕ СКРИПТЫ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo ""
echo "Машина: $CURRENT_HOST"
echo "Выполнено:"
echo "1. Настройка сетевых интерфейсов ✓"
echo "2. Настройка firewalld ✓"
if [[ "$CURRENT_HOST" == "hq-rtr.au-team.irpo" ]]; then
    echo "3. Настройка DHCP сервера ✓"
else
    echo "3. DHCP сервер (пропущено) - не требуется"
fi
echo "4. Создание пользователя net_admin ✓"
echo ""
echo "Пользователь для доступа:"
echo "  Логин: net_admin"
echo "  Пароль: P@\$\$word"
echo ""
echo "Текущий статус служб:"
echo "  firewalld: $(systemctl is-active firewalld)"
if [[ "$CURRENT_HOST" == "hq-rtr.au-team.irpo" ]]; then
    echo "  dhcpd: $(systemctl is-active dhcpd)"
fi
echo ""
echo "Готово!"