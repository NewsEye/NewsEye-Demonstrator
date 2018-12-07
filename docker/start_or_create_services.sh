#!/bin/bash

# if not root do nothing...
if [[ $EUID -ne 0 ]]; then
  echo "You must be root to allow data folder permission fix" 2>&1
  exit 1
else
    mkdir $PWD/dependencies
    wget https://ao.univ-lr.fr/index.php/s/e4oeaD6PW95BwGd/download -O dependencies/dependencies.zip
    cd dependencies
    unzip dependencies.zip
    rm dependencies.zip

    cd ..
    mkdir $PWD/docker_data_solr
    chown -R 8983:root $PWD/docker_data_solr
    chmod -R gu+rwx $PWD/docker_data_solr

    mkdir $PWD/docker_data_fcrepo
    chown -R 999:root $PWD/docker_data_fcrepo
    chmod -R gu+rwx $PWD/docker_data_fcrepo

    mkdir $PWD/docker_data_postgres
    chown -R 999:root $PWD/docker_data_postgres
    chmod -R gu+rwx $PWD/docker_data_postgres

    docker-compose up -d

    docker-compose exec --user "$(id -u):$(id -g)" website rails db:migrate
    docker-compose exec --user "$(id -u):$(id -g)" website rails db:seed
fi
