#!/bin/bash
# Полный установщик службы static routes для ALT Linux

set -e  # Прервать скрипт при любой ошибке

# --- 1. Проверяем права root ---
if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен с правами root (sudo)." >&2
   exit 1
fi

# --- 2. Создаём сам скрипт с маршрутами ---
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

# --- 3. Создаём службу systemd ---
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

# --- 4. Перезагружаем systemd и активируем службу ---
systemctl daemon-reload
systemctl enable add-my-routes.service
systemctl start add-my-routes.service

echo "✓ Служба добавлена в автозагрузку и запущена"

# --- 5. Проверяем результат ---
echo ""
echo "Проверяем статус службы:"
systemctl status add-my-routes.service --no-pager

echo ""
echo "Проверяем добавленные маршруты:"
ip route show | grep -E "192.168.100|192.168.200|172.16.7|172.16.8" || echo "Маршруты не найдены (возможно, ещё не применились)"

echo ""
echo "Complite"
echo "   To controll:"
echo "   sudo systemctl status add-my-routes.service  # status"
echo "   sudo systemctl restart add-my-routes.service # reboot"
echo "   sudo systemctl disable add-my-routes.service # autorun disable"