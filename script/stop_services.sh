#!/usr/bin/env bash

docker stop newseye_solr
docker rm newseye_solr
docker stop newseye_fcrepo
docker rm newseye_fcrepo
docker stop newseye_sas_solr
docker rm newseye_sas_solr
docker stop newseye_neo4j
docker rm newseye_neo4j
