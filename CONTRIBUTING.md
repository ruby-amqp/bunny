## Pre-requisites

The project uses Bundler for dependency management and requires RabbitMQ `3.5+` to be running
locally with the `rabbitmq-management` and `rabbitmq_consistent_hash_exchange` plugins enabled.


### Running the Specs

The specs require RabbitMQ to be running locally with a specific set of vhosts
and users. RabbitMQ can be provisioned and started any way that's convenient to you
as long as it has a suitable TLS keys configuration and management plugin enabled.
Make sure you have a recent version of RabbitMQ (> `3.5.3`).

You can also start a clean RabbitMQ server
node on your machine specifically for the bunny specs.
This can be done either by using a locally installed RabbitMQ server or by
running a RabbitMQ server in a Docker container.

#### Using a locally installed RabbitMQ server

Run the following command from the base directory of the gem:

```
RABBITMQ_NODENAME=bunny RABBITMQ_CONFIG_FILE=./spec/config/rabbitmq RABBITMQ_ENABLED_PLUGINS_FILE=./spec/config/enabled_plugins rabbitmq-server
```

The specs use the RabbitMQ management plugin and require a TLS port to
be available. The config files in the spec/config directory enable
these. TLS (x509 PEM) certificates include a hostname-specific fields,
the tests allow for expecting hostname overriding using the `BUNNY_RABBITMQ_HOSTNAME`
environment variables (default value is `127.0.0.1`).

Server, CA and client certificates can be found under `spec/tls`.
The location can be overridden via the `BUNNY_CERTIFICATE_DIR` environment variable.
It is supposed to target [tls-gen](https://github.com/michaelklishin/tls-gen)'s basic profile
output (result) directory on the host where specs are to be executed.

Next up you'll need to prepare your node for the specs (just once):

```
RABBITMQ_NODENAME=bunny ./bin/ci/before_build
```

The script uses `rabbitmqctl` and `rabbitmq-plugins`
to set up RabbitMQ in a way that Bunny test suites expect. Two environment variables,
`RABBITMQCTL` and `RABBITMQ_PLUGINS`, are available to control what `rabbitmqctl` and
`rabbitmq-plugins` commands will be used. By default they are taken from `PATH`
and prefixed with `sudo`.

And then run the core integration suite:

```
RABBITMQ_NODENAME=bunny CI=true rspec
```

#### Running a RabbitMQ server in a Docker container

First off you have to [install Docker Compose](https://docker.github.io/compose/install/) (and by proxy Docker).
Version >= 1.6.0+ is required for compose version 2 syntax.

After those have been installed (and the `docker-compose` command is available on your command line path), run

```
docker-compose up
```

The first time you do this, it will take some time, since it has to download everything it needs
to build the Docker image.

The RabbitMQ server will run in the foreground in the terminal where you started it. You can stop
it by pressing CTRL+C. If you want to run it in the background, run `docker-compose up -d`.

### Running Test Suites

Prior to running the tests, configure the RabbitMQ permissions by running `./bin/ci/before_build` 
if you have RabbitMQ locally installed, if you are running RabbitMQ via Docker as above this step 
is not required as the setup is baked in.

Make sure you have those two installed and then run integration tests:

    bundle install
    rake integration

It is possible to run all tests:

    bundle exec rspec -c

It is possible to run only integration and regression tests but exclude unit and stress tests:

    CI=true bundle exec rspec -c spec/higher_level_api/ spec/lower_level_api spec/issues && bundle exec rspec -c spec/higher_level_api/integration/connection_recovery_spec.rb

## Pull Requests

Then create a branch and make your changes on it. Once you are done with your changes and all
tests pass, write a [good, detailed commit message](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) submit a pull request on GitHub.
