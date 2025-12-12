#!/bin/bash
# Настройка docerk на BR-SRV

# Установка docekr
dnf install -y docker-ce docker-ce-cli docker-compose

# Создание ямлика
cat > /home/sshuser/wiki.yml << 'EOF'
# MediaWiki with MariaDB
#
# Access via "http://localhost:8080"
services:
  wiki:
    image: mediawiki
    restart: always
    ports:
      - 8080:80
    links:
      - mariadb
    volumes:
      - images:/var/www/html/images
      # After initial setup, download LocalSettings.php to the same directory as
      # this yaml and uncomment the following line and use compose to restart
      # the mediawiki service
      # - ./LocalSettings.php:/var/www/html/LocalSettings.php
  mariadb: # <- This key defines the name of the database during setup
    image: mariadb
    restart: always
    environment:
      # @see https://phabricator.wikimedia.org/source/mediawiki/browse/master/includes/DefaultSettings.php
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: wiki
      MYSQL_PASSWORD: WikiP@ssw0rd
      MYSQL_RANDOM_ROOT_PASSWORD: 'yes'
    volumes:
      - db:/var/lib/mysql

volumes:
  images:
  db:

EOF

systemctl enable --now docker
# Проверка подключения
echo "to start: docker-compose -f wiki.yml up -d"
echo "in BR-RTR: firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080:toaddr=192.168.200.3 --permanent"