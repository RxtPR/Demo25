#!/bin/bash
# Настройка Ansible на BR-SRV

# Установка Ansible
apt-get update
apt-get install -y ansible

# Создание рабочего каталога
mkdir -p /etc/ansible

# Создание inventory файла
cat > /etc/ansible/hosts << EOF
[hq-srv]
192.168.100.2 ansible_user=sshuser ansible_port=2024

[hq-cli]
172.16.7.3 ansible_user=sshuser ansible_port=2024

[hq-rtr]
172.16.4.2 ansible_user=net_admin

[br-rtr]
172.16.5.2 ansible_user=net_admin

[all:vars]
ansible_ssh_pass=P@ssw0rd  # для sshuser, для net_admin другой пароль
# Для net_admin пароль P@$$word, но в inventory нельзя указывать несколько разных паролей для разных групп? 
# Лучше указать переменные на уровне групп или хостов.
EOF

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
ansible_user=sshuser
ansible_port=2024
ansible_ssh_pass=P@ssw0rd

[hq-cli:vars]
ansible_user=sshuser
ansible_port=2024
ansible_ssh_pass=P@ssw0rd

[hq-rtr:vars]
ansible_user=net_admin
ansible_ssh_pass=P@$$word

[br-rtr:vars]
ansible_user=net_admin
ansible_ssh_pass=P@$$word
EOF

# Настройка SSH ключей (опционально, но для автоматизации лучше)
# Генерация ключа если нет
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
fi

# Копирование ключа на хосты (требует ввода пароля, поэтому пока пропустим)
# Для автоматизации можно использовать sshpass, но это не безопасно.
# Вместо этого, предложу пользователю скопировать ключ вручную.

echo "Для автоматического подключения скопируйте SSH ключ на удаленные хосты:"
echo "ssh-copy-id -p 2024 sshuser@192.168.100.2"
echo "ssh-copy-id -p 2024 sshuser@172.16.7.3"
echo "ssh-copy-id net_admin@172.16.4.2"
echo "ssh-copy-id net_admin@172.16.5.2"

# Проверка подключения
echo "Проверка подключения с помощью ansible ping..."
ansible all -m ping