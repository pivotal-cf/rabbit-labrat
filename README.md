# What is Lab Rat

This is an example Cloud Foundry app that used to inspect
values of environment variables available (e.g. `VCAP_SERVICES`)
and can be used to validate service health.

It is not useful more than as an example.


## How to Run It

    bundle install
    bundle exec puma

## How to Deploy

    # assuming you've done cf target and cf login
    # earlier
    cf push


## License

Released under the Apache 2.0 license

(c) 2013-2014, Pivotal Software
