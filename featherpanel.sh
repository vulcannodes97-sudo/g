#!/bin/bash
set -e


# ==============================
# DOMAIN INPUT
# ==============================
echo "======================================"
read -rp "🌐 Enter domain (panel.example.com): " DOMAIN
echo "======================================"

if [[ -z "$DOMAIN" ]]; then
  echo "❌ Domain required"
  exit 1
fi

# ==============================
# OS DETECT
# ==============================
. /etc/os-release
OS=$ID
CODENAME=$VERSION_CODENAME

echo "🧠 OS Detected: $OS ($CODENAME)"

# ==============================
# BASE REPOS
# ==============================
if [[ "$OS" == "ubuntu" ]]; then
   # Update the server
  apt update && apt upgrade -y
  # Add "add-apt-repository" command
  apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
  # Add additional repositories for PHP, Redis, and MariaDB
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
  # Update repositories list
  apt update
  # Add universe repository if you are on Ubuntu 18.04
  apt-add-repository universe
  # Install Dependencies
  apt -y install php8.5 php8.5-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis,mongodb,pgsql,pdo-pgsql} mariadb-server nginx tar unzip zip git redis-server make dos2unix || true
elif [[ "$OS" == "debian" ]]; then
   # Update the server
  apt update && apt upgrade -y
  # Install necessary packages
  apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release make
  # Add additional repositories for PHP, Redis, and MariaDB
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
  curl -fsSL https://packages.sury.org/php/ apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
  # Update repositories list
  apt update
  # Install PHP and required extensions
  apt install -y php8.5 php8.5-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis,mongodb,pgsql,pdo-pgsql}
  # MariaDB repo setup script
  curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
  # Install the rest of dependencies
  apt install -y mariadb-server nginx tar unzip git redis-server zip dos2unix
else
  echo "❌ Unsupported OS"
  exit 1
fi

# ==============================
# COMPOSER
# ==============================
curl -sS https://getcomposer.org/installer \
 | php -- --install-dir=/usr/local/bin --filename=composer

# ==============================
# NVM + NODE
# ==============================
apt install -y nodejs npm
npm install -g n
n lts
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm --version
nvm install --lts
npm install -g pnpm npm-check-updates
pnpm --version

# ==============================
# FEATHERPANEL
# ==============================
mkdir -p /var/www
cd /var/www
git clone https://github.com/mythicalltd/featherpanel.git featherpanel
chown -R www-data:www-data /var/www/featherpanel/*
cd /var/www/featherpanel

# ==============================
# BACKEND
# ==============================
COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir=/var/www/featherpanel/backend
pnpm install --dir /var/www/featherpanel/frontend/
# ==============================
# DATABASE
# ==============================
DB_NAME=featherpanel
DB_USER=featherpanel
DB_PASS=1234
mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"

# ==============================
# CRON
# ==============================
{ crontab -l 2>/dev/null | grep -v featherpanel || true
  echo "* * * * * bash /var/www/featherpanel/backend/storage/cron/runner.bash >/dev/null 2>&1"
  echo "* * * * * php  /var/www/featherpanel/backend/storage/cron/runner.php  >/dev/null 2>&1"
} | crontab -

# ==============================
# APP SETUP
# ==============================
php app setup
php app migrate
# ==============================
# FRONTEND
# ==============================
cd /var/www/featherpanel/frontend
pnpm build

# ==============================
# SSL (SELF-SIGNED)
# ==============================
mkdir -p /etc/certs/featherpanel
cd /etc/certs/featherpanel

openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

# ==============================
# NGINX CONFIG
# ==============================
rm -f /etc/nginx/sites-enabled/default

cat <<EOF > /etc/nginx/sites-available/FeatherPanel.conf
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/featherpanel/frontend/dist;
    index index.html;

    ssl_certificate /etc/certs/featherpanel/fullchain.pem;
    ssl_certificate_key /etc/certs/featherpanel/privkey.pem;

    client_max_body_size 100m;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:8721;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location ^~ /attachments/ { alias /var/www/featherpanel/backend/public/attachments/; }
    location ^~ /addons/      { alias /var/www/featherpanel/backend/public/addons/; }
    location ^~ /components/  { alias /var/www/featherpanel/backend/public/components/; }
}

server {
    listen 8721;
    server_name localhost;
    root /var/www/featherpanel/backend/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \\.php\$ {
        fastcgi_pass unix:/run/php/php8.5-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -sf /etc/nginx/sites-available/FeatherPanel.conf /etc/nginx/sites-enabled/FeatherPanel.conf
nginx -t && systemctl restart nginx

chown -R www-data:www-data /var/www/featherpanel/*

echo "======================================"
echo " ✅ FEATHERPANEL LIVE"
echo " 🌐 https://${DOMAIN}"
echo " ⚠️ Self-signed SSL (warning normal)"
echo "======================================"
