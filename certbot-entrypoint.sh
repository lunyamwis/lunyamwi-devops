#!/bin/sh

# Run Certbot commands for each subdomain
#[ -f /etc/letsencrypt/live/lunyamwi.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d lunyamwi.com
#[ -f /etc/letsencrypt/live/api.lunyamwi.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d api.lunyamwi.com
#[ -f /etc/letsencrypt/live/airflow.lunyamwi.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d airflow.lunyamwi.com
#[ -f /etc/letsencrypt/live/data.lunyamwi.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d data.lunyamwi.com
#[ -f /etc/letsencrypt/live/promptemplate.lunyamwi.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d promptemplate.lunyamwi.com
#[ -f /etc/letsencrypt/live/mqtt.lunyamwi.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d mqtt.lunyamwi.com

#certbot certonly -d api.lunyamwi.com --non-interactive
certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d api.lunyamwi.com
certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d data.lunyamwi.com
certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d mqtt.lunyamwi.com
certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d demo.lunyamwi.com
certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email lutherlunyamwi@gmail.com --agree-tos --no-eff-email --force-renewal -d airflow.lunyamwi.com
echo "done..."
## comments