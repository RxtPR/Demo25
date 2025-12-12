#!/bin/bash
# Автоматическая настройка BIND DNS сервера на RED OS (HQ-SRV)
# Содержит ТОЛЬКО записи из Таблицы 2 задания

set -e

# 1. Установка пакетов
echo "Установка BIND..."
dnf install -y bind bind-utils

# 2. Основная конфигурация
echo "Настройка /etc/named.conf..."
cat > /etc/named.conf << 'EOF'
options {
    listen-on port 53 { any; };
    listen-on-v6 port 53 { none; };
    directory "/var/named";
    
    allow-query { any; };
    allow-recursion { any; };
    
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    dnssec-validation auto;
};

# Прямая зона
zone "au-team.irpo" IN {
    type master;
    file "au-team.irpo.zone";
    allow-update { none; };
};

zone "16.172.in-addr.arpa" IN {
    type master;
    file "172.16.rev.zone";
    allow-update { none; };
};

zone "100.168.192.in-addr.arpa" IN {
    type master;
    file "192.168.100.rev.zone";
    allow-update { none; };
};

zone "200.168.192.in-addr.arpa" IN {
    type master;
    file "192.168.200.rev.zone";
    allow-update { none; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF

# 3. Создание файлов зон

# Прямая зона (ТОЛЬКО записи из таблицы)
echo "Создание прямой зоны..."
cat > /var/named/au-team.irpo.zone << 'EOF'
$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
        2024121201 ; Serial
        21600      ; Refresh
        3600       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

; NS запись
@          IN  NS  hq-srv.au-team.irpo.

; A
hq-rtr     IN  A   172.16.4.2
hq-srv     IN  A   192.168.100.2
hq-cli     IN  A   172.16.7.3
br-rtr     IN  A   172.16.5.2
br-srv     IN  A   192.168.200.2

; CNAME 
moodle     IN  CNAME hq-rtr.au-team.irpo.
wiki       IN  CNAME hq-rtr.au-team.irpo.
EOF

# Единая обратная зона для 172.16.X.X
echo "Создание единой обратной зоны для 172.16.X.X..."
cat > /var/named/172.16.rev.zone << 'EOF'
$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
        2024121201 ; Serial
        21600      ; Refresh
        3600       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

@          IN  NS  hq-srv.au-team.irpo.

; PTR 
2.4        IN  PTR hq-rtr.au-team.irpo.

3.7        IN  PTR hq-cli.au-team.irpo.
EOF

# Обратная зона для 192.168.100.0/26
echo "Создание обратной зоны для 192.168.100.0/26..."
cat > /var/named/192.168.100.rev.zone << 'EOF'
$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
        2024121201 ; Serial
        21600      ; Refresh
        3600       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

@          IN  NS  hq-srv.au-team.irpo.

; PTR
1          IN  PTR hq-rtr.au-team.irpo.    ; 192.168.100.1
2          IN  PTR hq-srv.au-team.irpo.    ; 192.168.100.2
EOF

# Обратная зона для 192.168.200.0/27
echo "Создание обратной зоны для 192.168.200.0/27..."
cat > /var/named/192.168.200.rev.zone << 'EOF'
$TTL 86400
@   IN  SOA hq-srv.au-team.irpo. admin.au-team.irpo. (
        2024121201 ; Serial
        21600      ; Refresh
        3600       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

@          IN  NS  hq-srv.au-team.irpo.

; PTR
1          IN  PTR br-rtr.au-team.irpo.    ; 192.168.200.1
EOF

# 4. Установка прав
chown named:named /var/named/*.zone
chmod 640 /var/named/*.zone

# 5. Проверка синтаксиса
echo "Проверка конфигурации..."
named-checkconf
named-checkzone au-team.irpo /var/named/au-team.irpo.zone
named-checkzone 16.172.in-addr.arpa /var/named/172.16.rev.zone
named-checkzone 100.168.192.in-addr.arpa /var/named/192.168.100.rev.zone
named-checkzone 200.168.192.in-addr.arpa /var/named/192.168.200.rev.zone

# 7. Часовой пояс (для Москвы)
echo "Установка часового пояса..."
timedatectl set-timezone Europe/Moscow

# 8. Запуск службы
echo "Запуск службы BIND..."
systemctl enable --now named
systemctl status named

echo "dns start"
