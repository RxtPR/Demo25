#!/bin/bash

# Проверяем, что мы на нужной машине
if [ "$(hostname)" != "ISP" ]; then
    echo "Ошибка: скрипт должен выполняться на ISP, а не на $(hostname)"
    echo "Переделывай"
    exit 1
fi

set -e  # Прерывать выполнение при любой ошибке

echo "=== Начинаю выполнение скриптов на машине ISP ==="
echo ""

# --- Функции из ip.sh ---
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

# --- 1. Выполняем ip.sh ---
echo "=== 1. Запуск ip.sh ==="
echo "Настраиваю ISP..."

DNS_SERVER="8.8.8.8"

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

# --- 2. Выполняем inet-isp.sh ---
echo "=== 2. Запуск inet-isp.sh ==="
echo "Настройка firewalld на ISP..."

# Проверяем наличие firewalld
if ! command -v firewall-cmd &> /dev/null; then
    echo "Установка firewalld..."
    apt-get update
    apt-get install -y firewalld
fi

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

echo ""
echo "✅ inet-isp.sh выполнен успешно"
echo ""

# --- 3. Выполняем route-isp.sh ---
echo "=== 3. Запуск route-isp.sh ==="
echo "Установка службы static routes..."

# Проверяем права root (уже root, но на всякий случай)
if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен с правами root (sudo)." >&2
   exit 1
fi

# Создаём сам скрипт с маршрутами
SCRIPT_PATH="/usr/local/bin/add-my-routes"
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
# Добавляем статические маршруты

ROUTES=(
    "192.168.100.0/26 via 172.16.4.2"
    "192.168.200.0/27 via 172.16.5.2"
    "172.16.7.0/28 via 172.16.4.2"
    "172.16.8.0/29 via 172.16.4.2"
)

for route in "${ROUTES[@]}"; do
    # Добавляем маршрут, игнорируем ошибку если уже существует
    ip route add $route 2>/dev/null || true
done
EOF

# Делаем скрипт исполняемым
chmod +x "$SCRIPT_PATH"
echo "✓ Скрипт с маршрутами создан: $SCRIPT_PATH"

# Создаём службу systemd
SERVICE_PATH="/etc/systemd/system/add-my-routes.service"
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Add custom static routes
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Служба systemd создана: $SERVICE_PATH"

# Перезагружаем systemd и активируем службу
systemctl daemon-reload
systemctl enable add-my-routes.service
systemctl start add-my-routes.service

echo "✓ Служба добавлена в автозагрузку и запущена"

# Проверяем результат
echo ""
echo "Проверяем статус службы:"
systemctl status add-my-routes.service --no-pager

echo ""
echo "Проверяем добавленные маршруты:"
ip route show | grep -E "192.168.100|192.168.200|172.16.7|172.16.8" || echo "Маршруты не найдены (возможно, ещё не применились)"

echo ""
echo "✅ route-isp.sh выполнен успешно"
echo ""

# --- Финальный отчет ---
echo "=== ВСЕ СКРИПТЫ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo ""
echo "Текущая конфигурация:"
echo "1. Сетевые интерфейсы настроены"
echo "2. Firewalld настроен и запущен"
echo "3. Статические маршруты добавлены через службу"
echo ""
echo "Команды для управления:"
echo "  sudo systemctl status add-my-routes.service  # статус службы маршрутов"
echo "  sudo systemctl restart add-my-routes.service # перезапуск службы"
echo "  sudo systemctl disable add-my-routes.service # отключить автозапуск"
echo ""
echo "Готово!"