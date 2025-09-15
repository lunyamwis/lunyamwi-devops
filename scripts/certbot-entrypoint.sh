#!/bin/sh

echo "Starting certbot..."
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d api.lunyamwi.org
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d demo.lunyamwi.org
certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d mqtt.lunyamwi.org
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d airflow.lunyamwi.org
# certbot certonly \
#   --dns-cloudflare \
#   --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini/cloudflare.ini \
#   --dns-cloudflare-propagation-seconds 60 \
#   -d lunyamwi.org \
#   -d '*.lunyamwi.org' \
#   --expand \
#   --non-interactive \
#   --agree-tos \
#   --email lutherlunyamwi@gmail.com 
echo "done..."
## comments
