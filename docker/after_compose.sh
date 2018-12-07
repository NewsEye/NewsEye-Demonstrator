#!/usr/bin/env bash

docker-compose exec --user "$(id -u):$(id -g)" website rails db:migrate
docker-compose exec --user "$(id -u):$(id -g)" website rails db:seed