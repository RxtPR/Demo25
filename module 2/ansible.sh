#!/bin/bash
# Настройка Ansible на BR-SRV

# Установка Ansible
dnf install -y ansible

# Создание рабочего каталога
mkdir -p /etc/ansible

# Создание inventory файла
# Но так как у нас два разных пользователя с разными паролями, то лучше указать переменные для каждой группы отдельно.
# Перепишем inventory:

cat > /etc/ansible/hosts << 'EOF'
[hq-srv]
192.168.100.2

[hq-cli]
172.16.7.3

[hq-rtr]
172.16.4.2

[br-rtr]
172.16.5.2

[hq-srv:vars]
ansible_port=2024
ansible_user=sshuser

[br-rtr:vars]
ansible_user=net_admin

[hq-rtr:vars]
ansible_user=net_admin
EOF

# Настройка SSH ключей (опционально, но для автоматизации лучше)
# Генерация ключа если нет
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
fi

# Копирование ключа на хосты (требует ввода пароля, поэтому пока пропустим)
# Для автоматизации можно использовать sshpass, но это не безопасно.
# Вместо этого, предложу пользователю скопировать ключ вручную.

echo "Copy to:"
echo "ssh-copy-id -p 2024 sshuser@192.168.100.2"
echo "ssh-copy-id root@172.16.7.3"
echo "ssh-copy-id net_admin@172.16.4.2"
echo "ssh-copy-id net_admin@172.16.5.2"

# Проверка подключения
echo "to test: ansible all -m ping"