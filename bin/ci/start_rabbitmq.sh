#!/bin/bash
if [ -z `which docker` ]; then
  echo 'You need to install docker to run this script. See https://docs.docker.com/engine/installation/'
  exit
fi

cd $(dirname $(readlink -f $0))
docker build -t bunny_rabbitmq ../../docker && \
exec docker run --net host -ti bunny_rabbitmq
