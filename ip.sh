#!/bin/bash
# Скрипт настройки сетевых интерфейсов для ISP, HQ-RTR и BR-RTR

set -e

# Определяем текущий хост
HOSTNAME=$(hostname)

# Общие настройки DNS
DNS_SERVER="8.8.8.8"

# Функция для настройки NetworkManager
configure_nm_connection() {
    local conn_name=$1
    local iface=$2
    local ip=$3
    local gateway=$4
    local dns=$5

    # Удаляем существующее подключение
    nmcli connection delete "$conn_name" 2>/dev/null || true
    
    # Создаем новое подключение
    if [[ "$ip" == "DHCP" ]]; then
        nmcli connection add type ethernet con-name "$conn_name" ifname "$iface" ipv4.method auto
    else
        nmcli connection add type ethernet con-name "$conn_name" ifname "$iface" ipv4.method manual ipv4.addresses "$ip"
        
        if [[ -n "$gateway" && "$gateway" != "none" ]]; then
            nmcli connection modify "$conn_name" ipv4.gateway "$gateway"
        fi
    fi
    
    # Настраиваем DNS
    if [[ -n "$dns" ]]; then
        nmcli connection modify "$conn_name" ipv4.dns "$dns"
    fi
    
    # Активируем подключение
    nmcli connection up "$conn_name"
}

# Функция для настройки VLAN интерфейса
configure_vlan() {
    local conn_name=$1
    local parent_iface=$2
    local vlan_id=$3
    local ip=$4
    local gateway=$5
    local dns=$6

    nmcli connection delete "$conn_name" 2>/dev/null || true
    
    # Создаем VLAN интерфейс
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

# Функция для настройки GRE туннеля
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

# Настройка в зависимости от хоста
case $HOSTNAME in
    "ISP")
        echo "Настраиваю ISP..."
        
        # Интерфейс enp0s3 (DHCP)
        configure_nm_connection "enp0s3-dhcp" "enp0s3" "DHCP" "" "$DNS_SERVER"
        
        # Интерфейс enp0s8 (статический)
        configure_nm_connection "enp0s8-static" "enp0s8" "172.16.4.1/28" "none" "$DNS_SERVER"
        
        # Интерфейс enp0s9 (статический)
        configure_nm_connection "enp0s9-static" "enp0s9" "172.16.5.1/28" "none" "$DNS_SERVER"
        
        # Включаем маршрутизацию
        sysctl -w net.ipv4.ip_forward=1
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        
        # Настраиваем правила маршрутизации между сетями
        echo "Настройка правил маршрутизации..."
        iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
        iptables -A FORWARD -i enp0s3 -o enp0s8 -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
        iptables -A FORWARD -i enp0s3 -o enp0s9 -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -i enp0s9 -o enp0s3 -j ACCEPT
        ;;
        
    "HQ-RTR")
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
        
        # Создаем соединение для enp0s8 без IP-адреса (только активация интерфейса)
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
        
    "BR-RTR")
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
        
    "HQ-SRV")
        echo "Настраиваю HQ-SRV..."
        
        # Настройка VLAN интерфейса
        nmcli connection delete "ens18-vlan100" 2>/dev/null || true
        
        nmcli connection add type vlan con-name "ens18-vlan100" ifname "ens18.100" \
            dev "ens18" id "100" ipv4.method manual ipv4.addresses "192.168.100.2/26" \
            ipv4.gateway "192.168.100.1" ipv4.dns "$DNS_SERVER"
        
        nmcli connection up "ens18-vlan100"
        ;;
        
    *)
        echo "Неизвестный хост: $HOSTNAME"
        echo "Ожидаемые имена: ISP, HQ-RTR, BR-RTR, HQ-SRV"
        exit 1
        ;;
esac

echo "Настройка завершена для $HOSTNAME"
echo ""
echo "Текущие подключения:"
nmcli connection show --active

echo ""
echo "Текущие IP-адреса:"
ip -4 addr show

echo ""
echo "Таблица маршрутизации:"
ip route show