FROM ubuntu:bionic

RUN apt-get -q update && \
    apt-get install -yq --no-install-recommends gnupg1 wget ca-certificates apt-transport-https

RUN echo 'deb https://dl.bintray.com/rabbitmq/debian bionic main erlang' > /etc/apt/sources.list.d/rabbitmq.list && \
    wget -O - 'https://dl.bintray.com/rabbitmq/Keys/rabbitmq-release-signing-key.asc' | apt-key add -

RUN apt-get -q update && \
    apt-get install -yq rabbitmq-server

COPY docker-entrypoint.sh /

ENTRYPOINT /docker-entrypoint.sh

EXPOSE 5671 5672 15672
