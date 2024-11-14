FROM ubuntu:24.04

RUN apt-get update -y
RUN apt-get install -y gnupg2 curl locales
RUN curl -1sLf 'https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA' | gpg --dearmor | tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
RUN curl -1sLf 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key' | gpg --dearmor | tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null
RUN curl -1sLf 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key' | gpg --dearmor | tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null

# Erlang expects UTF-8
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY apt/sources.list.d/rabbitmq.list /etc/apt/sources.list.d/rabbitmq.list

RUN apt-get update -y && apt-get upgrade -y

RUN apt-get install -y erlang-base \
                       erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                       erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                       erlang-runtime-tools erlang-snmp erlang-ssl \
                       erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

RUN apt-get install -y rabbitmq-server

COPY docker-entrypoint.sh /

ENTRYPOINT /docker-entrypoint.sh

EXPOSE 5671 5672 15672
