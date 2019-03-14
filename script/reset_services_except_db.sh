#!/usr/bin/env bash

docker stop newseye_solr
docker stop newseye_fcrepo

docker rm newseye_solr
docker rm newseye_fcrepo

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
docker run -d -t -p 8983:8983 -e SOLR_HEAP=4196m -v $DIR/../solr/config:/imported_config --name newseye_solr solr:7.5.0 solr-create -c hydra-development -d /imported_config
docker run -d -t -p 8984:8080 --name newseye_fcrepo lyrasis/fcrepo:4.7.4