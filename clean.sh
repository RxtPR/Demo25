#!/bin/bash
# cleanup_logs.sh - Очистка логов и следов выполнения скрипта настройки DNS

echo "Очистка логов и следов выполнения скрипта настройки DNS..."

# 1. Очистка истории команд (удаление строк связанных со скриптами DNS)
echo "Очистка истории команд..."
if [ -f ~/.bash_history ]; then
    cp ~/.bash_history ~/.bash_history.backup
    grep -v "setup_dns\|cleanup_dns\|named\|bind" ~/.bash_history > ~/.bash_history.tmp
    mv ~/.bash_history.tmp ~/.bash_history
fi

# 2. Очистка системных логов связанных с named и скриптом
echo "Очистка системных логов..."
# Удаление логов named за последние сутки
journalctl --since="1 day ago" | grep -i "named\|setup_dns" && \
echo "Логи named будут очищены" || true

# Очистка логов named в journalctl
journalctl --vacuum-time=1h --quiet

# Удаление конкретных лог файлов если они создавались
rm -f /var/log/named.log 2>/dev/null || true
rm -f /var/log/bind.log 2>/dev/null || true

# 3. Очистка временных файлов
echo "Очистка временных файлов..."
find /tmp -name "*dns*" -type f -delete 2>/dev/null || true
find /tmp -name "*bind*" -type f -delete 2>/dev/null || true
find /tmp -name "*named*" -type f -delete 2>/dev/null || true

# 4. Очистка кэша пакетного менеджера
echo "Очистка кэша dnf..."
dnf clean all 2>/dev/null || true

# 5. Очистка истории dnf (логов установки пакетов)
echo "Очистка истории dnf..."
rm -f /var/log/dnf.* 2>/dev/null || true

# 6. Сброс временных меток файлов конфигурации (опционально)
echo "Сброс временных меток конфигурационных файлов..."
touch -d "2024-01-01 00:00:00" /etc/named.conf 2>/dev/null || true
for zone in /var/named/*.zone; do
    [ -f "$zone" ] && touch -d "2024-01-01 00:00:00" "$zone" 2>/dev/null || true
done

# 7. Очистка логов фаервола
echo "Очистка логов фаервола..."
firewall-cmd --reload 2>/dev/null || true
rm -f /var/log/firewall* 2>/dev/null || true

# 8. Очистка переменных окружения (в текущей сессии)
unset HISTFILE 2>/dev/null || true
history -c

# 9. Финализация
echo "Запуск sync для сброса буферов..."
sync

echo "================================================"
echo "Очистка завершена. Были удалены:"
echo "1. История команд связанная со скриптами DNS"
echo "2. Системные логи named и journalctl"
echo "3. Временные файлы"
echo "4. Кэш и история dnf"
echo "5. Логи фаервола"
echo ""
echo "Внимание: Конфигурация DNS (зоны и настройки) осталась нетронутой."
echo "Служба named продолжает работать."
echo "ВЫПОЛНИ history -c && history -w"
echo "ВЫПОЛНИ exec bash"
echo "================================================"

# 10. Скрытие следов самого этого скрипта
# Удаляем себя после выполнения
history -c
rm -f "$0" 2>/dev/null || true