#!/bin/bash

# if not root do nothing...
if [[ $EUID -ne 0 ]]; then
  echo "You must be root to allow data folder permission fix" 2>&1
  exit 1
else
    if [ ! -d "$PWD/dependencies" ]; then
        mkdir $PWD/dependencies
        wget --no-check-certificate https://nextcloud.lr17.fr/index.php/s/KnK7mBhVjDk7jd3/download -O dependencies/dependencies.zip
        cd dependencies
        unzip dependencies.zip
        rm dependencies.zip
        cd ..
    fi

    mkdir $PWD/docker_data_solr
    chown -R 8983:root $PWD/docker_data_solr
    chmod -R gu+rwx $PWD/docker_data_solr

    mkdir $PWD/docker_data_fcrepo
    chown -R 999:root $PWD/docker_data_fcrepo
    chmod -R gu+rwx $PWD/docker_data_fcrepo

    mkdir $PWD/docker_data_postgres
    chown -R 999:root $PWD/docker_data_postgres
    chmod -R gu+rwx $PWD/docker_data_postgres

    # replace config to work with docker
    sed -i 's/localhost:8984/fcrepo:8984/g' $PWD/../config/fedora.yml
    sed -i 's/localhost:8983/solr:8983/g' $PWD/../config/solr.yml
    sed -i 's/host: localhost/host: postgres/g' $PWD/../config/database.yml
    sed -i 's/ocalhost:8983/solr:8983/g' $PWD/../config/blacklight.yml

    docker-compose up -d --build

    docker-compose exec --user "$(id -u):$(id -g)" website rails db:migrate
    docker-compose exec --user "$(id -u):$(id -g)" website rails db:seed
fi
