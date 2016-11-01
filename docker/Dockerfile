FROM debian:jessie

RUN apt-get -q update && \
    apt-get install -yq --no-install-recommends wget ca-certificates

RUN echo 'deb http://www.rabbitmq.com/debian/ testing main' > /etc/apt/sources.list.d/rabbitmq.list && \
    wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | apt-key add -

RUN apt-get -q update && \
    apt-get install -yq --no-install-recommends rabbitmq-server

COPY docker-entrypoint.sh /

ENTRYPOINT /docker-entrypoint.sh

EXPOSE 5671 5672 15672