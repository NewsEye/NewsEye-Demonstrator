#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
docker run -d -t -p 8983:8983 -v $DIR/../solr/config:/imported_config --name newseye_solr solr:7.5.0 solr-create -c hydra-development -d /imported_config
docker run -d -t -p 8984:8080 --name newseye_fcrepo lyrasis/fcrepo:4.7.4
docker run -d -t -p 5432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=newseye_development --name newseye_postgres postgres:11