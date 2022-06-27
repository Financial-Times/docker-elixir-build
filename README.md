# Docker Elixir Build Image Base

This builds a Docker image that can be used as a base to build Elixir (and Erlang) projects.

## Important

Make sure not to build this image on your MacBook with a M1 processor and push it to Nexus. Jenkins WILL NOT work with it. M1 images of this builder will only work when building docker containers locally. In order to push an image for Nexus, upload the file to the Jenkins server and build and push it from there. Only then will the image be with the correct architecture. (This statement will no longer be valid once Docker allows compatibility between the M1 processors and the rest of the architectures)

## Contents

As of `elixir-build:2.3.0`:

* Erlang 24.3.3
* Elixir 1.11.4
* Node 8.9.3 (npm 5.5.1)
* `make`, `git`
* `openssl`

`hex` and `rebar` are also installed.

## A multi-stage minimal image build

With the new [Docker multi-stage builds](https://docs.docker.com/engine/userguide/eng-image/multistage-build/) facility (17.05+) it is now simple to write a single `Dockerfile` that can build an Elixir project, and create a minimal run-time image using simply `docker build`.

Assuming [distillery](https://github.com/bitwalker/distillery) is set up, and its `rel/config.exs` is configured for a stand-alone ERTS release as so:

```elixir
environment :docker do
  set dev_mode: false
  set include_erts: true
  set include_src: false
  set cookie: :crypto.hash(:sha256, :crypto.rand_bytes(25)) |> Base.encode16 |> String.to_atom
end
```

Then a `Dockerfile` to build a minimal run-time image for a [Phoenix](http://www.phoenixframework.org/) project may look like:

```dockerfile
FROM nexus.in.ft.com:5000/membership/elixir-build:2.2.0 AS build

WORKDIR /build

COPY mix.exs .
COPY mix.lock .
COPY deps deps

ARG MIX_ENV=docker
ARG APP_VERSION=0.0.0
ENV MIX_ENV ${MIX_ENV}
ENV APP_VERSION ${APP_VERSION}

RUN mix deps.get

COPY lib lib
COPY test test
COPY config config
COPY rel rel

# Uncomment line below if you have assets in the priv dir
# COPY priv priv

# Build Phoenix assets
COPY assets assets
RUN cd assets && npm install && ./node_modules/.bin/brunch build --production
RUN mix phx.digest


RUN mix release --env=${MIX_ENV}

### Minimal run-time image
FROM alpine:latest

RUN apk --no-cache update && apk --no-cache upgrade && apk --no-cache add ncurses-libs openssl bash ca-certificates

RUN adduser -D app

ARG MIX_ENV=docker
ARG APP_VERSION=0.0.0

ENV MIX_ENV ${MIX_ENV}
ENV APP_VERSION ${APP_VERSION}

WORKDIR /opt/app

# Copy release from build stage
COPY --from=build /build/_build/${MIX_ENV}/rel/* ./

USER app

# Mutable Runtime Environment
RUN mkdir /tmp/app
ENV RELEASE_MUTABLE_DIR /tmp/app
ENV START_ERL_DATA /tmp/app/start_erl.data

# Start command
# NB 'myapp' should be replaced by your application name, as per mix.exs
CMD ["/opt/app/bin/myapp", "foreground"]
```

This uses [`distillery`](https://github.com/bitwalker/distillery) to build a the stand-alone release in one stage, and then copies the release artefacts from the first stage to a second stage, starting afresh from the minimal Alpine base image. Adds additional package `openssl` to `libcrypto.so` is available at runtime, YMMV.

NB the `APP_VERSION` environment var is used in the `mix.exs` above to set the version, e.g.:

```elixir
  @version System.get_env("APP_VERSION") || "0.0.0"

  def project do
    [app: :myapp,
     version: @version,
     ...
```

so passing it as a `--build-arg` allows the release version to be set, making the whole build image command for a project simply:

```
docker build --build-arg APP_VERSION=1.1.2 .
```