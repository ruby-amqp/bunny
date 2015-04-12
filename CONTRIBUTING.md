## Pre-requisites

The project uses Bundler for dependency management and requires RabbitMQ `3.4+` to be running
locally. Prior to running the tests, configure the RabbitMQ permissions
by running `./bin/ci/before_script`. Make
sure you have those two installed and then run tests:

    bundle install
    bundle exec rspec -cfd spec/    

## Pull Requests

Then create a branch and make your changes on it. Once you are done with your changes and all
tests pass, write a [good, detailed commit message](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) submit a pull request on GitHub.
