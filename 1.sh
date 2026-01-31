read DOMAIN
DOMAIN=${DOMAIN:-panel.example.com}
apt update && apt upgrade -y
apt install curl wget git sudo -y
apt install -y mariadb-server mariadb-client openssl
curl -fsSL https://get.docker.com/ | sh
mkdir -p /var/www/convoy
cd /var/www/convoy
curl -Lo panel.tar.gz https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R o+w storage/* bootstrap/cache/
DB_NAME=panel
DB_USER=pterodactyl
DB_PASS=yourPassword
mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "CREATE DATABASE ${DB_NAME};"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"
cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env
sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=a_secure_password|g" .env
sed -i "s|APP_ENV=.*|APP_ENV=production|g" .env
sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" .env


docker compose up -d
docker compose exec workspace bash -c "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
docker compose exec workspace bash -c "php artisan key:generate --force && \
                                       php artisan optimize"
docker compose exec workspace php artisan migrate --force
docker compose exec workspace php artisan c:user:make
docker compose down
docker compose up -d --build
docker compose exec workspace bash -c "php artisan optimize"
docker compose restart
