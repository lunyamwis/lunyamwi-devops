#!/bin/bash

## globals
service_name="installboostedchat"
update_service_name="updateboostedchat"
my_ip=$(curl -s ifconfig.me) #dig +short myip.opendns.com @resolver1.opendns.com # wget -qO- ipinfo.io/ip
hostname=$(sed 's/\n//g' /etc/hostname) # assume hostname to be the new username

isValidIp() {
    local ip="$1"
    local ip_pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$"  # IPv4 pattern

    if [[ "$ip" =~ $ip_pattern ]]; then
        return 0  # Valid IP address
    else
        return 1  # Invalid IP address
    fi
}

getMyIP() {
    my_ip=$(curl -s ifconfig.me)
    if ! isValidIp "$my_ip"; then 
        my_ip=$(dig +short myip.opendns.com @resolver1.opendns.com) 
        if ! isValidIp "$my_ip"; then 
            my_ip=$(wget -qO- ipinfo.io/ip) 
            if ! isValidIp "$my_ip"; then
                echo "Failed to retrieve the IP address." >&2
                exit 1
            fi
        fi
    fi
    echo "$my_ip"
}


env_var=$1
# Check if DEV_ENV environment variable is set
if [ "$env_var" == "dev" ]; then
    BRANCH="dev"
else
    BRANCH="main"
fi

echo "env=${env_var}"

## Check if the service already exists
serviceExists() {
    local service_file="/etc/systemd/system/$service_name.service"

    if [ -f "$service_file" ]; then
        return 0  # Service file exists
    else
        return 1  # Service file does not exist
    fi
}


copyDockerYamls() {
    if [ "$BRANCH" == "dev" ]; then
        save_docker_yaml
        save_docker_airflow_yaml
    fi
}

editNginxConf() {
    dir=$(pwd)
    cd /root/boostedchat-site

    sed -i 's/$http_host/127.0.0.1/g' ./nginx-conf/nginx.conf

    sed -i "s/jamel/$hostname/g" ./nginx-conf/*
    sed -i "s/jamel/$hostname/g" ./nginx-conf.1/*

    cd "$dir"
}



createService() {
    local current_dir=$(pwd)
    local script_name=$(basename "$0")
    local service_file="/etc/systemd/system/$service_name.service"

    # Create the service unit file
    cat <<EOF > "/etc/systemd/system/$service_name.service"
[Unit]
Description=Setup Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$current_dir/
Environment="HOME=/root"
ExecStart=$current_dir/$script_name $env_var
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the newly added unit files
    sudo systemctl daemon-reload

    # Start and enable the service
    sudo systemctl start $service_name
    sudo systemctl enable $service_name

    # Check service status
    sudo systemctl status $service_name
}


createUpdateService() {
    saveWatch #/root/watch.sh
    local current_dir=$(pwd)
    local script_name="watch.sh"
    local service_file="/etc/systemd/system/$update_service_name.service"

    sudo systemctl stop $service_name
    sudo systemctl disable $service_name
    if [ -f "/etc/systemd/system/$update_service_name.service" ]; then
        sudo rm /etc/systemd/system/$service_name.service
    fi
    # Create the service unit file
    cat <<EOF > "/etc/systemd/system/$update_service_name.service"
[Unit]
Description=Update boostedchat service
After=network.target

[Service]
Type=simple
WorkingDirectory=$current_dir/
Environment="HOME=/root"
ExecStart=$current_dir/$script_name
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the newly added unit files
    sudo systemctl daemon-reload

    # Start and enable the service
    sudo systemctl start $update_service_name
    sudo systemctl enable $update_service_name

    # Check service status
    sudo systemctl status $update_service_name
}


initialSetup() {
    sudo apt update
    sudo apt install docker.io -y

    # install docker compose plugins
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

    sudo apt install git -y


    ssh-keyscan GitHub.com > /root/.ssh/known_hosts #2>&1 >/dev/null
    ssh-keyscan GitHub.com > ~/.ssh/known_hosts #2>&1 >/dev/null
    chmod 644 ~/.ssh/known_hosts
    chmod 600 ~/.ssh/id_rsa_git
    chmod 644 /root/.ssh/known_hosts
    chmod 600 /root/.ssh/id_rsa_git

    # git clone -o StrictHostKeyChecking=no git@github.com:LUNYAMWIDEVS/boostedchat-site.git
    GIT_SSH_COMMAND='ssh -i /root/.ssh/id_rsa_git -o StrictHostKeyChecking=no' git clone -b $BRANCH git@github.com:LUNYAMWIDEVS/boostedchat-site.git

    cd boostedchat-site

    saveCertbotEntry # before directory is created
    echo "Created certbot entry point file"
    ls -lha

    ## nginx-config files
    cp -r ./nginx-conf ./nginx-conf.1
    rm -rf ./nginx-conf
    mkdir ./nginx-conf 
    # I think having both files in nginx-conf causes the error with the client container before ssl certificate is configured
    # cp ./nginx-conf/nginx.conf ./nginx-conf/nginx.ssl.conf 
    # cp ./nginx-conf/nginx.nossl.conf ./nginx-conf/nginx.conf
    cp ./nginx-conf.1/nginx.nossl.conf ./nginx-conf/nginx.conf
    #


    # sed -i 's/$http_host/127.0.0.1/g' ./nginx-conf/nginx.conf

    # sed -i "s/jamel/$hostname/g" ./nginx-conf/*
    # sed -i "s/jamel/$hostname/g" ./nginx-conf.1/*
    editNginxConf

    ## set up env variables
    cp /etc/boostedchat/.env ./


    ## change db name in docker-compose.yaml
    sed -i "s/POSTGRES_DB: jamel/POSTGRES_DB: $hostname/g" docker-compose.yaml  # This is hardcoded

    ### change database name
    sed -i "s/^POSTGRES_DBNAME=.*/POSTGRES_DBNAME=\"$hostname\"/" .env
    echo >> .env.example
    # echo "HOSTNAME=$hostname" >> .env
    ## echo "DOMAIN1=$hostname" >> .env
    ## echo "DOMAIN2=$hostname" >> .env
    sed -i "s/^DOMAIN1=.*/DOMAIN1=\"$hostname\"/" .env
    sed -i "s/^DOMAIN2=.*/DOMAIN2=\"$hostname\"/" .env
    sed -i "s/__HOSTNAME__/$hostname/g" .env
    

    # random_string1=$(openssl rand -out /dev/stdout 32 | base64 -w 0)
    # random_string2=$(openssl rand -out /dev/stdout 32 | base64 -w 0)
    # random_string3=$(openssl rand -out /dev/stdout 32 | base64 -w 0)


    # sed -i "s/__GENERIC_STR1__/$random_string1/g" .env
    # sed -i "s/__GENERIC_STR2__/$random_string2/g" .env
    # sed -i "s/__GENERIC_STR3__/$random_string3/g" .env
    generate_random_string() {
        length=$((RANDOM % 9 + 24))  # Generate random length between 24 and 32
        openssl rand -out /dev/stdout "$length" | base64 -w 0 | sed 's/=//g' | sed 's/[^[:alnum:]]//g'
    }

    # Loop until all occurrences of __GENERIC_STR__ are replaced
    while grep -q "__GENERIC_STR1__" .env; do
        # Generate random string
        random_string=$(generate_random_string)

        # Replace placeholders in .env file with random string
        sed -i "s/__GENERIC_STR1__/$random_string/g" .env
    done
    while grep -q "__GENERIC_STR2__" .env; do
        # Generate random string
        random_string=$(generate_random_string)

        # Replace placeholders in .env file with random string
        sed -i "s/__GENERIC_STR2__/$random_string/g" .env
    done
    while grep -q "__GENERIC_STR3__" .env; do
        # Generate random string
        random_string=$(generate_random_string)

        # Replace placeholders in .env file with random string
        sed -i "s/__GENERIC_STR3__/$random_string/g" .env
    done

    source <(sed 's/^/export /' .env ) >/dev/null  # is this really necessary, or does docker export the variables in .env by itself?

    # if [ "$BRANCH" == "dev" ]; then
    #     save_docker_yaml
    #     save_docker_airflow_yaml
    # fi
    copyDockerYamls

    ## log in to docker 
    docker login --username $DOCKER_USERNAME --password $DOCKER_PASSWORD

    ## Start the services defined in the docker-compose.airflow.yaml file
    docker compose -f docker-compose.airflow.yaml up --build -d


    ## Edit postgres-etl port
    sed -i "s/^#port = 5432/port = 5433/" /opt/postgres-etl-data/postgresql.conf

    ### restart
    docker compose -f docker-compose.airflow.yaml restart postgresetl
    docker compose -f docker-compose.airflow.yaml up --build -d
    docker compose up --build -d

    ## Edit prompt-factory
    sleep 10 ## seems to require some time before starting
    sed -i "s/^#port = 5432/port = 5434/" /opt/postgres-promptfactory-data/postgresql.conf

    docker compose restart postgres-promptfactory

    #cp ./nginx-conf/nginx.ssl.conf ./nginx-conf/nginx.conf

    docker compose up --build -d --force-recreate

    ## Check logs of containers that have exited
    docker ps -a --filter "status=exited" --filter "exited=1" --format "{{.ID}} {{.Image}}" | while read -r container_id image_name; do echo ""; echo ""; echo ""; echo ""; echo ""; echo ""; echo "Container ID: $container_id, Image Name: $image_name"; docker logs "$container_id"; done
    sleep 60
    # where will we read the 
    ## for some reason one accepts --username while the other complains of missing --username
    docker compose exec -e "DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD" api python manage.py createsuperuser --email="$DJANGO_SUPERUSER_EMAIL"  --noinput --username "$DJANGO_SUPERUSER_EMAIL" ||     docker compose exec -e "DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD" api python manage.py createsuperuser --email="$DJANGO_SUPERUSER_EMAIL"  --noinput

    docker compose exec -e "DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD" prompt python manage.py createsuperuser --email="$DJANGO_SUPERUSER_EMAIL"  --noinput --username "$DJANGO_SUPERUSER_EMAIL" || docker compose exec -e "DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD" prompt python manage.py createsuperuser --email="$DJANGO_SUPERUSER_EMAIL"  --noinput
}

projectCreated() {
    local project_dir="/root/boostedchat-site"
     if [ ! -d "$project_dir" ]; then
        return 1  
    else 
        return 0
    fi
}



# Function to test subdomains and write results to a file
test_sites() {
    source <(sed 's/^/export /' ~/boostedchat-site/.env ) >/dev/null  
    cd ~
    local subdomain_="$hostname"
    local domain="boostedchat.com"
    subdomains=(
        "${subdomain_}.${domain}"
        "airflow.${subdomain_}.${domain}"
        "api.${subdomain_}.${domain}"
        "promptemplate.${subdomain_}.${domain}"
        "scrapper.${subdomain_}.${domain}"
    )
    echo "Subject: Tests for $hostname" > results.txt
    echo "Content-Type: text/html" >> results.txt
    echo "" >> results.txt
    echo "<p><b>SERVERS:</b></p>" >> results.txt
    for subdomain in "${subdomains[@]}"; do
        if [[ "$subdomain" == api.* ]]; then
            subdomain="$subdomain/admin/login/?next=/admin/"
        fi
        if [[ "$subdomain" == airflow.* ]]; then
            subdomain="$subdomain/login/"
        fi
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$subdomain")
        if [ "$response_code" == "200" ]; then
            echo "$subdomain: 200 OK<br>" >> results.txt
        else
            echo "$subdomain: $response_code<br>" >> results.txt
        fi
    done

    cd /root/boostedchat-site
    echo "<p><b>DATABASES:</b></p>" >> ../results.txt
    if docker compose exec postgres psql -h "localhost" -U "postgres" -d "$hostname" -p 5432 -c "SELECT 1;" > /dev/null 2>&1; then
        echo "postgres: Connection successful<br>" >> ../results.txt
        else
        echo "postgres: Connection failed<br>" >> ../results.txt
    fi 
    if docker compose -f /root/boostedchat-site/docker-compose.airflow.yaml exec postgresetl  psql -h "localhost" -U "postgres" -d "etl" -p 5433 -c "SELECT 1;" > /dev/null 2>&1; then
        echo "postgresetl: Connection successful<br>" >> ../results.txt
        else
        echo "postgresetl: Connection failed<br>" >> ../results.txt
    fi 
    if docker compose exec postgres-promptfactory  psql -h "localhost" -U "postgres" -d "promptfactory" -p 5434 -c "SELECT 1;" > /dev/null 2>&1; then
        echo "promptfactory: Connection successful<br>" >> ../results.txt
        else
        echo "promptfactory: Connection failed<br>" >> ../results.txt
    fi 

    cd ..
    
    
    sendmail "$INSTANCES_EMAIL" < results.txt
}

subdomainSet() {
    if certificates_exist; then 
        return 0
    fi
    local subdomain_="$hostname"
    local domain="boostedchat.com"
    subdomains=(
        "${subdomain_}.${domain}"
        "airflow.${subdomain_}.${domain}"
        "api.${subdomain_}.${domain}"
        "promptemplate.${subdomain_}.${domain}"
        "scrapper.${subdomain_}.${domain}"
        "mqtt.${subdomain_}.${domain}"
    )

    my_ip=$(getMyIP)
    if [ $? -eq 0 ]; then
        echo "My IP address is: $my_ip"
    else
        echo "Failed to retrieve my IP address ($my_ip)."
        return 1
    fi
    # local subdomain="$hostname.boostedchat.com"
    # local resolved_ip=$(dig +short "$subdomain")

    # if [ "$resolved_ip" == "$my_ip" ]; then
    #     echo "The subdomain $subdomain points to the expected IP address: $my_ip"
    #     return 0  # Success
    # else
    #     echo "The subdomain $subdomain does not point to the expected IP address ($my_ip). Resolved IP: $resolved_ip"
    #     return 1  # Failure
    # fi
    success_flag=0
    # Iterate over each subdomain and check its resolved IP address
    for subdomain in "${subdomains[@]}"; do
        resolved_ip=$(dig +short "$subdomain")
        if [ "$resolved_ip" == "$my_ip" ]; then
            echo "The subdomain $subdomain points to the expected IP address: $my_ip"
        else
            echo "The subdomain $subdomain does not point to the expected IP address ($my_ip). Resolved IP: $resolved_ip"
            return 1
        fi
    done
    return 0
}

stopAndRemoveService() {
    sudo systemctl disable $service_name
    sudo rm /etc/systemd/system/$service_name.service
    sudo systemctl daemon-reload
    sudo systemctl stop $service_name
}

certificates_exist() {
    local file_exists=false

    # Iterate through each container
    for container_id in $(docker ps -q); do
        # docker exec "$container_id" test -e "/etc/letsencrypt/live/$hostname.boostedchat.com/privkey.pem" && file_exists=true
        if docker exec "$container_id" test -e "/etc/letsencrypt/live/$hostname.boostedchat.com/privkey.pem"; then
            # Return true if the file exists in any container
            return 0
        fi
    done
    return 1
}

runCertbot() {
    cd /root/boostedchat-site
    saveCertbotEntry
    sed -i "s/jamel/$hostname/g" certbot-entrypoint.sh

    # if ! certificates_exist; then 
        # check if certificate already exist
        docker compose restart certbot
        echo "Waiting for certbot to run"
        sleep 60 
        docker logs certbot
        
        cp ./nginx-conf.1/nginx.conf ./nginx-conf/nginx.conf
        docker compose up --build -d --force-recreate
    # fi
    
}

## leave the lines that follow as is. It is used as a line_marker for a function which will be created here by copy_dev_docker_file.sh
save_docker_yaml() {
    cat <<'DOC_EOF' > /root/boostedchat-site/docker-compose.yaml
version: "3"

services:
  api:
    image: lunyamwimages/boostedchatapi-dev:latest
    restart: always
    ports:
      - "8000:8000"
    volumes:
      - web-django:/usr/src/app
      - web-static:/usr/src/app/static
    env_file:
      - .env
    entrypoint: ["/bin/bash", "+x", "/entrypoint.sh"]
    networks:
      - booksy

  postgres:
    image: postgres:latest
    container_name: postgres-container
    env_file:
      - .env
    environment:
      POSTGRES_USER: ${POSTGRES_USERNAME}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DBNAME}
    volumes:
      - /opt/postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - booksy
  
  postgres-promptfactory:
    image: postgres:latest
    container_name: postgres-promptfactory-container
    env_file:
      - .env
    environment:
      POSTGRES_USER: ${POSTGRES_PROMPTFACTORY_USERNAME}
      POSTGRES_PASSWORD: ${POSTGRES_PROMPTFACTORY_PASSWORD}
      POSTGRES_DB: ${POSTGRES_PROMPTFACTORY_DBNAME}
    volumes:
      - /opt/postgres-promptfactory-data:/var/lib/postgresql/data
    ports:
      - "5434:5434"
    networks:
      - booksy

  client:
    image: lunyamwimages/boostedchatui-dev:latest
    restart: always
    env_file:
      - .env
    depends_on:
      - api
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - web-root:/usr/share/nginx/html
      - ./nginx-conf/:/etc/nginx/conf.d
      - certbot-etc:/etc/letsencrypt
      - certbot-var:/var/lib/letsencrypt
      - ./dhparam:/etc/ssl/certs
    networks:
      - booksy

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - certbot-etc:/etc/letsencrypt
      - certbot-var:/var/lib/letsencrypt
      - web-root:/usr/share/nginx/html
      - ./certbot-entrypoint.sh:/certbot-entrypoint.sh  # Mounting the script
    entrypoint: ["/bin/sh", "-c"]
    depends_on:
      - client
    # command: certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d ${DOMAIN2}.boostedchat.com -d api.${DOMAIN2}.boostedchat.com -d airflow.${DOMAIN2}.boostedchat.com -d scrapper.${DOMAIN2}.boostedchat.com -d promptemplate.${DOMAIN2}.boostedchat.com
    command: /certbot-entrypoint.sh
    networks:
      - booksy

  mqtt:
    image: lunyamwimages/boostedchatmqtt-dev:latest
    restart: always
    ports:
      - "1883:1883"
      - "8883:8883"
      - "3000:3000"
    volumes:
      - ../mqtt-logs:/usr/src/app/logs
    env_file:
      - .env
    networks:
      - booksy

  prompt:
    image: lunyamwimages/promptfactory-dev:latest
    restart: always
    depends_on:
      - api
    ports:
      - "8001:8001"
    networks:
      - booksy
    env_file:
      - .env

  salesrep:
    image: lunyamwimages/boostedchatamqp
    env_file:
      - .env
    networks:
      - booksy

  message-broker:
    image: rabbitmq:3-management-alpine
    container_name: message-broker
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq/
      - rabbitmq-log:/var/log/rabbitmq
    restart: always
    networks:
      - booksy
  redis1:
    image: redis:latest
    expose:
      - 6379
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "6379", "ping"]
      interval: 10s
      timeout: 30s
      retries: 50
      start_period: 30s
    restart: always
    ports:
      - "6380:6379"
    volumes:
      - redisdata1:/data
    networks:
      - booksy

volumes:
  web-django:
  web-static:
  certbot-etc:
  certbot-var:
  rabbitmq-data:
  rabbitmq-log:
  web-root:
  dhparam:
  redisdata1:

networks:
  booksy:
    external: true
    name: booksy-talk
DOC_EOF
    echo "Docker YAML content saved successfully."
}


save_docker_airflow_yaml() {
    cat <<'DOC_EOF' > /root/boostedchat-site/docker-compose.airflow.yaml
version: "3"
x-airflow-common:
  &airflow-common
  # In order to add custom dependencies or upgrade provider packages you can use your extended image.
  # Comment the image line, place your Dockerfile in the directory where you placed the docker-compose.yaml
  # and uncomment the "build" line below, Then run `docker-compose build` to build the images.
  image: ${AIRFLOW_IMAGE_NAME:-apache/airflow:2.8.1}
  # build: .
  environment:
    &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: CeleryExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://postgres:${POSTGRES_PASSWORD_ETL}@postgresetl:5433/etl
    AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://postgres:${POSTGRES_PASSWORD_ETL}@postgresetl:5433/etl
    AIRFLOW__CELERY__BROKER_URL: redis://:@redis:6379/0
    AIRFLOW__CORE__FERNET_KEY: ''
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
    AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session'
    # yamllint disable rule:line-length
    # Use simple http server on scheduler for health checks
    # See https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/check-health.html#scheduler-health-check-server
    # yamllint enable rule:line-length
    AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
    # WARNING: Use _PIP_ADDITIONAL_REQUIREMENTS option ONLY for a quick checks
    # for other purpose (development, test and especially production usage) build/extend Airflow image.
    _PIP_ADDITIONAL_REQUIREMENTS: ${_PIP_ADDITIONAL_REQUIREMENTS:-}
  volumes:
    - ${AIRFLOW_PROJ_DIR:-.}/dags:/opt/airflow/dags
    - ${AIRFLOW_PROJ_DIR:-.}/logs:/opt/airflow/logs
    - ${AIRFLOW_PROJ_DIR:-.}/config:/opt/airflow/config
    - ${AIRFLOW_PROJ_DIR:-.}/plugins:/opt/airflow/plugins
  user: "${AIRFLOW_UID:-50000}:0"
  depends_on:
    &airflow-common-depends-on
    redis:
      condition: service_healthy
    
services:
  web:
    restart: always
    image: lunyamwimages/scrapper-dev:latest
    expose:
      - "8003"
    ports:
      - "8003:8003"
    links:
      - redis:redis
    volumes:
      - web-django:/usr/src/app
      - web-static:/usr/src/app/static
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
      - ./config:/opt/airflow/config
      - ./plugins:/opt/airflow/plugins
    networks:
      - booksy
      
    env_file: .env
    environment:
      DEBUG: "true"
    entrypoint: ["/bin/bash", "+x", "/entrypoint.sh"]
  
  postgresetl:
    image: postgres:latest
    container_name: postgres-etl-container
    env_file:
      - .env
    environment:
      POSTGRES_USER: ${POSTGRES_USERNAME_ETL}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD_ETL}
      POSTGRES_DB: ${POSTGRES_DBNAME_ETL}
    volumes:
      - /opt/postgres-etl-data:/var/lib/postgresql/data
    expose:
      - "5433"
    ports:
      - "5433:5433"
    networks:
      - booksy
    
  redis:
    image: redis:latest
    expose:
      - 6379
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 30s
      retries: 50
      start_period: 30s
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    networks:
      - booksy

  airflow-webserver:
    <<: *airflow-common
    command: webserver
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
    - booksy

  airflow-scheduler:
    <<: *airflow-common
    command: scheduler
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8974/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
    - booksy

  airflow-worker:
    <<: *airflow-common
    command: celery worker
    healthcheck:
      # yamllint disable rule:line-length
      test:
        - "CMD-SHELL"
        - 'celery --app airflow.providers.celery.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}" || celery --app airflow.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}"'
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    environment:
      <<: *airflow-common-env
      # Required to handle warm shutdown of the celery workers properly
      # See https://airflow.apache.org/docs/docker-stack/entrypoint.html#signal-propagation
      DUMB_INIT_SETSID: "0"
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    
    networks:
      - booksy

  airflow-triggerer:
    <<: *airflow-common
    command: triggerer
    healthcheck:
      test: ["CMD-SHELL", 'airflow jobs check --job-type TriggererJob --hostname "$${HOSTNAME}"']
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - booksy

  airflow-init:
    <<: *airflow-common
    entrypoint: /bin/bash
    # yamllint disable rule:line-length
    command:
      - -c
      - |
        if [[ -z "${AIRFLOW_UID}" ]]; then
          echo
          echo -e "\033[1;33mWARNING!!!: AIRFLOW_UID not set!\e[0m"
          echo "If you are on Linux, you SHOULD follow the instructions below to set "
          echo "AIRFLOW_UID environment variable, otherwise files will be owned by root."
          echo "For other operating systems you can get rid of the warning with manually created .env file:"
          echo "    See: https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html#setting-the-right-airflow-user"
          echo
        fi
        one_meg=1048576
        mem_available=$$(($$(getconf _PHYS_PAGES) * $$(getconf PAGE_SIZE) / one_meg))
        cpus_available=$$(grep -cE 'cpu[0-9]+' /proc/stat)
        disk_available=$$(df / | tail -1 | awk '{print $$4}')
        warning_resources="false"
        if (( mem_available < 4000 )) ; then
          echo
          echo -e "\033[1;33mWARNING!!!: Not enough memory available for Docker.\e[0m"
          echo "At least 4GB of memory required. You have $$(numfmt --to iec $$((mem_available * one_meg)))"
          echo
          warning_resources="true"
        fi
        if (( cpus_available < 2 )); then
          echo
          echo -e "\033[1;33mWARNING!!!: Not enough CPUS available for Docker.\e[0m"
          echo "At least 2 CPUs recommended. You have $${cpus_available}"
          echo
          warning_resources="true"
        fi
        if (( disk_available < one_meg * 10 )); then
          echo
          echo -e "\033[1;33mWARNING!!!: Not enough Disk space available for Docker.\e[0m"
          echo "At least 10 GBs recommended. You have $$(numfmt --to iec $$((disk_available * 1024 )))"
          echo
          warning_resources="true"
        fi
        if [[ $${warning_resources} == "true" ]]; then
          echo
          echo -e "\033[1;33mWARNING!!!: You have not enough resources to run Airflow (see above)!\e[0m"
          echo "Please follow the instructions to increase amount of resources available:"
          echo "   https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html#before-you-begin"
          echo
        fi
        mkdir -p /sources/logs /sources/dags /sources/plugins
        chown -R "${AIRFLOW_UID}:0" /sources/{logs,dags,plugins}
        exec /entrypoint airflow version
    # yamllint enable rule:line-length
    environment:
      <<: *airflow-common-env
      _AIRFLOW_DB_MIGRATE: 'true'
      _AIRFLOW_WWW_USER_CREATE: 'true'
      _AIRFLOW_WWW_USER_USERNAME: ${_AIRFLOW_WWW_USER_USERNAME:-airflow}
      _AIRFLOW_WWW_USER_PASSWORD: ${_AIRFLOW_WWW_USER_PASSWORD:-airflow}
      _PIP_ADDITIONAL_REQUIREMENTS: ''
    user: "0:0"
    volumes:
      - ${AIRFLOW_PROJ_DIR:-.}:/sources
    networks:
      - booksy

  airflow-cli:
    <<: *airflow-common
    profiles:
      - debug
    environment:
      <<: *airflow-common-env
      CONNECTION_CHECK_MAX_COUNT: "0"
    # Workaround for entrypoint issue. See: https://github.com/apache/airflow/issues/16252
    command:
      - bash
      - -c
      - airflow
    networks:
      - booksy

  # You can enable flower by adding "--profile flower" option e.g. docker-compose --profile flower up
  # or by explicitly targeted on the command line e.g. docker-compose up flower.
  # See: https://docs.docker.com/compose/profiles/
  flower:
    <<: *airflow-common
    command: celery flower
    profiles:
      - flower
    ports:
      - "5555:5555"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:5555/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - booksy

  

volumes:
  web-django:
  web-static:
  redisdata:
  letsencrypt:
  postgres-etl-data:


networks:
  booksy:
    name: booksy-talk
DOC_EOF
    echo "Docker YAML content saved successfully."
}

savePullUpdatedImages() {
    cat <<'DOC_EOF' > /root/pullUpdatedImages.sh
#!/bin/bash

cd /root/boostedchat-site
# Find the docker-compose file
compose_file=$(find . -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \))

if [ -z "$compose_file" ]; then
    echo "No docker-compose.yml or docker-compose.yaml found."
    exit 1
fi

# Function to check if image needs update
needs_update() {
    local image="$1"
    local status=$(docker pull "$image" | grep -o "Status: Image is up to date")
    echo "$image: $status"
    if [ -z "$status" ]; then
        return 0
    else
        return 1
    fi
}

# Restart services if needed
services_to_restart=()
images=$(grep -E '^\s+image:' "$compose_file" | awk '{print $2}')
for image in $images; do
    if needs_update "$image"; then
        services_to_restart+=($(grep -E '^\s+image:' "$compose_file" | grep -B1 "$image" | grep -o '^\s\+\S\+:' | sed 's/://'))
    fi
done

if [ ${#services_to_restart[@]} -eq 0 ]; then
    echo "No services need to be restarted."
else
    echo "Restarting services:"
    for service in "${services_to_restart[@]}"; do
        echo "Restarting $service"
        docker compose -f "$compose_file" restart "$service"
    done
fi
DOC_EOF
    chmod +x /root/pullUpdatedImages.sh
    echo "pullUpdatedImages.sh content saved successfully."
}

saveWatch() {
    cat <<'DOC_EOF' > /root/watch.sh
#!/bin/bash

which inotifywait || apt install inotify-tools -y
# Check if inotifywait is installed
command -v inotifywait >/dev/null 2>&1 || { echo >&2 "inotifywait is required but it's not installed. Aborting."; exit 1; }

# Define the file to watch
file_to_watch="/root/update"

# if [ ! -f "/root/watch.sh" ]; then
    touch "$file_to_watch"
# fi


# Function to execute when file changes
on_file_change() {
    echo "File $file_to_watch has been modified. Running update scripts"
    ## pull updates
    /bin/bash /root/pullUpdatedImages.sh
}

# Watch for changes in the file
while true; do
    inotifywait -e modify "$file_to_watch"
    on_file_change
done

# changed something on watch...
DOC_EOF
    chmod +x /root/watch.sh
    echo "watch.sh content saved successfully."
}


saveCertbotEntry() {
    cat <<'DOC_EOF' > /root/boostedchat-site/certbot-entrypoint.sh
#!/bin/sh

# Run Certbot commands for each subdomain
[ -f /etc/letsencrypt/live/jamel.boostedchat.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d jamel.boostedchat.com
[ -f /etc/letsencrypt/live/api.jamel.boostedchat.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d api.jamel.boostedchat.com
[ -f /etc/letsencrypt/live/airflow.jamel.boostedchat.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d airflow.jamel.boostedchat.com
[ -f /etc/letsencrypt/live/scrapper.jamel.boostedchat.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d scrapper.jamel.boostedchat.com
[ -f /etc/letsencrypt/live/promptemplate.jamel.boostedchat.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d promptemplate.jamel.boostedchat.com
[ -f /etc/letsencrypt/live/mqtt.jamel.boostedchat.com/privkey.pem ] || certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email tomek@boostedchat.com --agree-tos --no-eff-email --force-renewal -d mqtt.jamel.boostedchat.com

echo "done..."
## comments
DOC_EOF
    chmod +x certbot-entrypoint.sh
    echo "certbot-entrypoint.sh content saved successfully."
}

FUNCTION="$2"

if [ "$#" -eq 2 ]; then
    # Call the specified function
    echo $FUNCTION
    case "$FUNCTION" in
        "copyDockerYamls")
            copyDockerYamls
            ;;
        "editNginxConf")
            editNginxConf
            ;;
        *)
            echo "Invalid function name"
            exit 1
            ;;
    esac
    exit 0
fi

# trigger updates


if [ ! -f "/root/watch.sh" ]; then
    createUpdateService
fi

if [ ! -f "/root/pullUpdatedImages.sh" ]; then
    savePullUpdatedImages
fi

source <(sed 's/^/export /' /etc/boostedchat/.env ) >/dev/null 

if ! serviceExists; then
    ./sendEmail.sh "Creating $hostname" "Creating install service"
    createService
else 
    if ! projectCreated; then
        ./sendEmail.sh "Creating $hostname" "Running initial setup"
        initialSetup
    else
        copyDockerYamls             # just in case there are any updates
        if subdomainSet; then
            ./sendEmail.sh "Creating $hostname" "Running certbot"
            runCertbot
            cd ~
            ./sendEmail.sh "Done creating $hostname" "Instance is ready\n. Try logging in to $hostname.boostedchat.com"
            test_sites
            stopAndRemoveService
        else
            while ! subdomainSet; do
                ./sendEmail.sh "Creating $hostname" "Waiting for subdomain propagation"
                echo "Checking again in 60 seconds"
                sleep 60  # Wait for 60 seconds before checking again
            done
            runCertbot
            cd ~
            ./sendEmail.sh "Done creating $hostname" "Instance is ready!"
            test_sites
            stopAndRemoveService
        fi
    fi
fi


### just a change to trigger