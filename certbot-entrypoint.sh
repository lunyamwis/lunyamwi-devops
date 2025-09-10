#!/bin/sh

# Run Certbot commands for each subdomain
#[ -f /etc/letsencrypt/live/lunyamwi.org/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d lunyamwi.org
#[ -f /etc/letsencrypt/live/api.lunyamwi.org/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d api.lunyamwi.org
#[ -f /etc/letsencrypt/live/airflow.lunyamwi.org/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d airflow.lunyamwi.org
#[ -f /etc/letsencrypt/live/data.lunyamwi.org/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d data.lunyamwi.org
#[ -f /etc/letsencrypt/live/promptemplate.lunyamwi.org/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d promptemplate.lunyamwi.org
#[ -f /etc/letsencrypt/live/mqtt.lunyamwi.org/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d mqtt.lunyamwi.org

#certbot certonly -d api.lunyamwi.org --non-interactive
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d api.lunyamwi.org
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d lunyamwi.org
certbot certonly --manual --preferred-challenges dns -d '*.lunyamwi.org' -d lunyamwi.org
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d mqtt.lunyamwi.org
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d demo.lunyamwi.org
# certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.org --agree-tos --no-eff-email --force-renewal -d airflow.lunyamwi.org
echo "done..."
## comments
