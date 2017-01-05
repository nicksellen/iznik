# running iznik under docker

This is a work in progress so expect rough edges and frequent changes.

Make sure you have
[docker](https://docs.docker.com/engine/getstarted/step_one/#step-1-get-docker) and
[docker compose](https://docs.docker.com/compose/install/)
installed, and that docker is running.

Setup should then be something like:

```
docker-compose up
./docker/load-schema.sh
./docker/composer-install.sh
```

Then you _should_ be able to visit [localhost:59000](http://localhost:59000).
