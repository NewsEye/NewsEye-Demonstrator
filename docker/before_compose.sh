#!/usr/bin/env bash

mkdir $PWD/docker_data_solr
chown -R 8983:root $PWD/docker_data_solr
chmod -R gu+rwx $PWD/docker_data_solr

mkdir $PWD/docker_data_fcrepo
chown -R 999:root $PWD/docker_data_fcrepo
chmod -R gu+rwx $PWD/docker_data_fcrepo

mkdir $PWD/docker_data_postgres
chown -R 999:root $PWD/docker_data_postgres
chmod -R gu+rwx $PWD/docker_data_postgres