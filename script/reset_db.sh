#!/usr/bin/env bash

docker stop newseye_postgres
docker rm newseye_postgres
docker run -d -t -p 5432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=newseye_development --name newseye_postgres postgres:11