#!/bin/bash

set -e

MYSQL_PASSWORD=root

function sql-query() {
  local database=$1 query=$2;
  docker-compose exec -T db sh -c "mysql -p$MYSQL_PASSWORD $database -e \"$query\""
}

function sql-file() {
  local database=$1 filename=$2;
  docker-compose exec -T db sh -c "mysql -p$MYSQL_PASSWORD $database < /app/$filename"
}

function exec-in-container() {
  local container=$1; shift;
  local command=$@;
  docker-compose exec -T --user $(id -u):$(id -g) $container sh -c "HOME=./ $command"
}

function run-in-container() {
  local container=$1; shift;
  local command=$@;
  docker-compose run -T --rm --user $(id -u):$(id -g) $container sh -c "HOME=./ $command"
}

function composer() {
  local command=$@;
  docker-compose run \
    --rm \
    app \
    sh -c \
    "cd /app/composer && composer $command; chown -R $(id -u):$(id -g) vendor"
}
