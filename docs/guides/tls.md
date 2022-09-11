---
title: "TLS (SSL) connections to RabbitMQ from Ruby with Bunny"
layout: article
---

## About This Guide

This guide covers TLS (SSL) connections to RabbitMQ with Bunny.

This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
GitHub](https://github.com/ruby-amqp/rubybunny.info).


## What version of Bunny does this guide cover?

This guide covers Bunny 2.11.0 and later versions.


## TLS Support in RabbitMQ

RabbitMQ version 3.x supports TLS/SSL on Erlang R16B03 or later. Using the most
recent version (e.g. `17.1` or `17.1`) is recommended.

To use TLS with RabbitMQ, you need a few things:

 * Server certificate and private key
 * [Configure RabbitMQ to use TLS](http://www.rabbitmq.com/ssl.html)
 * CA certificate that signs the server certificate
 * Client certificate and private (optional if peer verification is disabled)


## Generating Certificates For Development

The easiest way to generate a CA, server and client keys and
certificates is by using
[tls-gen](https://github.com/ruby-amqp/tls-gen/). It requires
`openssl` and `make` to be available.

See [RabbitMQ TLS/SSL guide](http://www.rabbitmq.com/ssl.html) for
more information about TLS support on various platforms.


## Enabling TLS/SSL Support in RabbitMQ

TLS/SSL support is enabled using two arguments:

 * `ssl_listeners` (a list of ports TLS connections will use)
 * `ssl_options` (a proplist of options such as CA certificate file location, server key file location, and so on)

 An example that requires client certificate and performs client authentication:

``` erlang
[
  {rabbit, [
     {ssl_listeners, [5671]},
     {ssl_options, [{cacertfile,"/path/to/testca/cacert.pem"},
                    {certfile,"/path/to/server/cert.pem"},
                    {keyfile,"/path/to/server/key.pem"},
                    {verify,verify_peer},
                    {fail_if_no_peer_cert,true}]}
   ]}
].
```

 An example that requires no client certificate and performs no authentication
 (not recommended for production):

``` erlang
[
  {rabbit, [
     {ssl_listeners, [5671]},
     {ssl_options, [{cacertfile,"/path/to/testca/cacert.pem"},
                    {certfile,"/path/to/server/cert.pem"},
                    {keyfile,"/path/to/server/key.pem"},
                    {verify,verify_none},
                    {fail_if_no_peer_cert,false}]}
   ]}
].
```

Note that all paths must be absolute (no `~` and other shell-isms) and be readable
by the OS user RabbitMQ uses.

Learn more in the [RabbitMQ TLS/SSL guide](http://www.rabbitmq.com/ssl.html).

## Connecting to RabbitMQ from Bunny Using TLS/SSL

There are several options `Bunny.new` takes:

 * `:tls` which, when set to `true`, will set SSL context up and switch to TLS port (5671)
 * `:tls_cert` which is a string path to the client certificate (public key) in PEM format
 * `:tls_key` which is a string path to the client key (private key) in PEM format
 * `:tls_ca_certificates` which is an array of string paths to CA certificates in PEM format
 * `:verify_peer` which determines if TLS peer authentication (verification) is performed, `true` by default

An example:

``` ruby
conn = Bunny.new(:tls                   => true,
                 :tls_cert              => "examples/tls/client_cert.pem",
                 :tls_key               => "examples/tls/client_key.pem",
                 :tls_ca_certificates   => ["./examples/tls/cacert.pem"],
                 # convenient for dev/QA, please enable in production
                 :verify_peer           => false)
```

If you configure RabbitMQ to accept TLS connections on a separate port, you need to
specify both `:tls` and `:port` options:

``` ruby
conn = Bunny.new(:tls                   => true,
                 # custom port RabbitMQ TLS listener is configured to use
                 :port                  => 6778,
                 :tls_cert              => "examples/tls/client_cert.pem",
                 :tls_key               => "examples/tls/client_key.pem",
                 :tls_ca_certificates   => ["./examples/tls/cacert.pem"],
                 # convenient for dev/QA, please enable in production
                 :verify_peer           => false)
```

Paths can be relative but it's recommended to use absolute paths and no symlinks
to avoid issues with path expansion.

### Inline Certificates and Keys

In cases when reading files from the filesystem is not an option, it
is possible to provide certificates and keys inline:

``` ruby
cert = <<-EOS
-----BEGIN CERTIFICATE-----
MIIC8zCCAdugAwIBAgIBATANBgkqhkiG9w0BAQUFADAiMREwDwYDVQQDEwhNeVRl
c3RDQTENMAsGA1UEBxMEMTgxNTAeFw0xMzA2MDIxNTU0MDBaFw0xNDA2MDIxNTU0
MDBaMCcxFDASBgNVBAMTC2dpb3ZlLmxvY2FsMQ8wDQYDVQQKEwZjbGllbnQwggEi
MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDj70Z3cs873uTdONh/gK0vEI75
okTHOQBz9QPVUx0c+cdUvp1Ct1FXBYM4Jq47aaRW5vuki0SeML0gdrQouSVFtblX
HnB8bYF1oMlkmTrIDvM9DT5H3AMiQbbypVkRjQBb/Rs97sr+P05jhK2ZWxTxzs3W
kqdblJaxfMX7IXgvobnXDJO0PcN7tzOOlcD8dGFABLEtzWRmzqVvrJ7tZh0klsiB
I2yuOjk9LZhNcgmSNUAln+MFkWiAQcwWvl77DSBVPqIi6w6Q0oJoS6gsT6jOfw3f
ApX7Fjoib3UXLrZC2Fe7Sq03joZcpL7lMqsEZCZr0VqASQJHoTPqEknSMlpxAgMB
AAGjLzAtMAkGA1UdEwQCMAAwCwYDVR0PBAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUF
BwMCMA0GCSqGSIb3DQEBBQUAA4IBAQCFpfTUD9CjkrlhJi8GrryRlBILah45HIH4
MuUEUaGE//glCTuKXHjUhgtFSkFaDr0Xq50ckUzMVdmsQpSZM3N1F/eTicIk1PzY
b+7t86/XC5wct94I5yxPNX7S8VwHtK8yav0WwMwEGmduTxfjMPnJBDPdwIp6LgiF
BqM4Hh8HxHdr+MxOg3JGiodM7MMsDs1A05RiBcR3RzMvbXn5eQIy7tHOJMnrdbj9
mOrfKAmRlWyNj3mhOVpae22sbtSxHYZ10b0Xp/KFusiZCfQvo4pERonjUoMLtaPE
RtPrRrHy96dzmpVFnDVaA+CKZqyBncVAT0zQ3lIJdFIOEbE//s06
-----END CERTIFICATE-----
EOS

key = <<-EOS
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA4+9Gd3LPO97k3TjYf4CtLxCO+aJExzkAc/UD1VMdHPnHVL6d
QrdRVwWDOCauO2mkVub7pItEnjC9IHa0KLklRbW5Vx5wfG2BdaDJZJk6yA7zPQ0+
R9wDIkG28qVZEY0AW/0bPe7K/j9OY4StmVsU8c7N1pKnW5SWsXzF+yF4L6G51wyT
tD3De7czjpXA/HRhQASxLc1kZs6lb6ye7WYdJJbIgSNsrjo5PS2YTXIJkjVAJZ/j
BZFogEHMFr5e+w0gVT6iIusOkNKCaEuoLE+ozn8N3wKV+xY6Im91Fy62QthXu0qt
N46GXKS+5TKrBGQma9FagEkCR6Ez6hJJ0jJacQIDAQABAoIBACfSlCMmYeJ57M5h
siGEn71LTU979DxCTzvzILpSjRGU6ih6LQuM758ejXBwAZzLtjSgonJ7CoAAz+ou
EwfSYRquxzTbUpfKogWlE8qJouV1BzYxbCIt5DZF+OqnzMnuMpPfwrStVbXZ5Z4p
fhL/AMfGc9v7P1YWvcVAoW5gyJi5ejL4az82ZHqDltkkPBm7yXI1xaoAuAU+ir4X
AArDQWqqD+lPVD8gtMfyRYek7xL/O2SZUAVNQC14Fi2gmh01FFW/gnPmoT7GutEL
gfdEQ1KpyzquaSf1u/cka9jbdqf2fAhMj6UwasIJ1HF8dzblzO/nB+cTzIo9LzoK
erwQs2ECgYEA/nTWap6M7InOeAkosEEeLcu0idnjxlT/OToRtfdNkKatvqAFpSDd
2IBzr3kH+qGToeF8B7uJBaWO69m28+yEngWNW1u0KICUTTzlKZqSqNy1nxWnCWVk
Eg9LtEja4ncoWufbxBB6wwptk4RSqB9HUeZSQf8CG5MvDCLmEsMwwLUCgYEA5VFA
FSZJ3X96nGHlrokq7yDNAQLVZ72B+X+SRt7b9FMVeTyT7fQCAjFSiZYR0Tuz8XEn
STARp27K8OyFv0L1ZzHeywRcqICo9Eqa4Q/Juw+Waf3F40f1lxXb09OTHI/JedWz
U+VMX/OgsFW4a/3/L+IatlnBKemTKvhd94E5VE0CgYEAsQtcMLz2cpIDrXM580Cr
ndORXyTSnamAFzI3JnPWbSH725l9tAIlOUFOvLWqfpEzpju8T6kFUn957NIDwL49
G7HjQ8CPnmqwRPlsvUDGcGV4nSK0oQ4BzasE0oCqg03DL1UJjOamc9Rqn2w/EqkI
t4xYiYDD16nV30zc5gsXfc0CgYBLlwvbrOJeXB4rnG2cqeR4LMTG14tHBgXpG285
Y07368dBToGox20+EcoWRlybLuXy6Yy8qFa5bWECJ8Uytby1BpBdNZPhi3+l/02s
cIrb2ZiIWbm4YMkIw5DR84UjvhX4zkOtnQEfA+ztE2SWXISY4RxTDaUJzs/PM02u
P2+JZQKBgFcOXsnCR/x1CQ6j90pqXjvAK6x/Aiwx0FFTtcPdDft/zuJzav1Co84u
vUGvUADy1AVUB5ERz3z6us9gA4tUIeNwlQ0XFQXVT7I7GBXO3eF5PeiCXfThqnm9
dHgVP3fRaFosQv7mQe6BuuUHP3TJwT1qv/cWmiyyc1Xs7L2b4YU/
-----END RSA PRIVATE KEY-----
EOS

conn = Bunny.new(:tls                   => true,
                 :tls_cert              => cert,
                 :tls_key               => key,
                 :tls_ca_certificates   => ["./examples/tls/cacert.pem"],
                 # convenient for dev/QA, please enable in production
                 :verify_peer           => false)
```


### Providing Certificates & Keys When Using amqps:// URIs

It is possible to use `amqps://` URIs in combination with additional
options, e.g. to provide TLS certificate and key paths:

``` ruby
c = Bunny.new("amqps://bunny_gem:bunny_password@127.0.0.1/bunny_testbed",
        :tls_cert              => "spec/tls/client_cert.pem",
        :tls_key               => "spec/tls/client_key.pem",
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"],
        # convenient for dev/QA, please enable in production
        :verify_peer           => false)
c.start
```

### Peer Verification

In some situations it is reasonable to disable peer verification
(authentication), which is enabled by default. This means TLS will only be used for encryption
and not authentication, enabling man-in-the-middle (MITM) attacks. This
is a reasonable thing to do in development but **we highly recommend using
peer verification in production environments**.

To disable peer with Bunny, use `:verify_peer`:

``` ruby
c = Bunny.new("amqps://bunny_gem:bunny_password@127.0.0.1/bunny_testbed",
        :tls_cert              => "spec/tls/client_cert.pem",
        :tls_key               => "spec/tls/client_key.pem",
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"],
        :verify_peer           => false)
c.start
```

When disabling peer verification, make sure RabbitMQ is also
configured to not verify peer. In such case, it is possible
to forego providing client certificate and private key:

``` ruby
c = Bunny.new("amqps://bunny_gem:bunny_password@127.0.0.1/bunny_testbed",
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"],
        :verify_peer           => false)
c.start
```

Disabling peer verification is not recommended for production.



## Default Paths for TLS/SSL CA's

### CA Certificate Paths Inference

Bunny will use CA certificate paths used by OpenSSL if OpenSSL can
provide this information. When using self-signed certificates with
a custom certificate authority, it is possible to place CA certificates
to a system location.

To detect the location, run the following code in the REPL after
loading OpenSSL:

```
irb -ropenssl
```

``` ruby
ENV[OpenSSL::X509::DEFAULT_CERT_DIR_ENV] || OpenSSL::X509::DEFAULT_CERT_DIR
# => "/usr/local/etc/openssl/certs"
```

### On Linux

Bunny will use the following TLS/SSL CA's paths on Linux by default:

 * `/etc/ssl/certs/ca-certificates.crt` on Ubuntu/Debian
 * `/etc/ssl/certs/ca-bundle.crt` on Amazon Linux
 * `/etc/ssl/ca-bundle.pem` on OpenSUSE
 * `/etc/pki/tls/certs/ca-bundle.crt` on Fedora/RHEL

and will log a warning if no CA files are available via default paths
or `:tls_ca_certificates`.


## TLS/SSL Versions Support

Bunny will use TLSv1 through TLSv1.2 when available, and fall back
to [insecure](https://www.openssl.org/~bodo/ssl-poodle.pdf) SSLv3 if that's the only version supported.

Note that **RabbitMQ will reject SSLv3 connections** unless configured otherwise,
starting with 3.4.0.


## Known TLS Vulnerabilities: POODLE, BEAST, etc

### POODLE
              
[POODLE](https://www.openssl.org/~bodo/ssl-poodle.pdf) is a known
SSL/TLS attack that originally compromised SSLv3.  Starting with
version 3.4.0, RabbitMQ server refuses to accept SSLv3 connections. In
December 2014, a modified version of the POODLE attack that affects
TLSv1.0 was [announced](https://www.imperialviolet.org/2014/12/08/poodleagain.html).
It is therefore recommended to disable TLSv1.0 support (see below)
when possible.

### BEAST

[BEAST attack](http://en.wikipedia.org/wiki/Transport_Layer_Security#BEAST_attack)
is a known vulnerability that affects TLSv1.0. To mitigate it, disable
TLSv1.0 support (see below).

## Disabling SSL/TLS Versions via Configuration

To limit enabled SSL/TLS protocol versions, use the `versions` option in RabbitMQ
configuration:

```
%% Disable SSLv3.0 support, leaves TLSv1.0 enabled.
[
 {ssl, [{versions, ['tlsv1.2', 'tlsv1.1', tlsv1]}]},
 {rabbit, [
           {ssl_listeners, [5671]},
           {ssl_options, [{cacertfile,"/path/to/ca_certificate.pem"},
                          {certfile,  "/path/to/server_certificate.pem"},
                          {keyfile,   "/path/to/server_key.pem"},
                          {versions, ['tlsv1.2', 'tlsv1.1', tlsv1]}
                         ]}
          ]}
].
```

```
%% Disable SSLv3.0 and TLSv1.0 support.
[
 {ssl, [{versions, ['tlsv1.2', 'tlsv1.1']}]},
 {rabbit, [
           {ssl_listeners, [5671]},
           {ssl_options, [{cacertfile,"/path/to/ca_certificate.pem"},
                          {certfile,  "/path/to/server_certificate.pem"},
                          {keyfile,   "/path/to/server_key.pem"},
                          {versions, ['tlsv1.2', 'tlsv1.1']}
                         ]}
          ]}
].
```

to verify, use `openssl s_client`:

```
# connect using SSLv3
openssl s_client -connect 127.0.0.1:5671 -ssl3
```

```
# connect using TLSv1.0 through v1.2
openssl s_client -connect 127.0.0.1:5671 -tls1
```

and look for the following in the output:

```
SSL-Session:
  Protocol  : TLSv1
```

## What to Read Next

The documentation is organized as [a number of
guides](/articles/guides.html), covering various topics.


## Tell Us What You Think!

Please take a moment to tell us what you think about this guide [on
Twitter](http://twitter.com/rubyamqp) or the [Bunny mailing
list](https://groups.google.com/forum/#!forum/ruby-amqp)

Let us know what was unclear or what has not been covered. Maybe you
do not like the guide style or grammar or discover spelling
mistakes. Reader feedback is key to making the documentation better.
