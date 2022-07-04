FROM bitwalker/alpine-erlang:24.3.3

ENV ELIXIR_VERSION 1.11.4

RUN apk --no-cache upgrade
RUN apk --no-cache add git make
RUN apk --no-cache add openssl

RUN apk --no-cache add --virtual build-dependencies wget ca-certificates && \
    wget --no-check-certificate https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/Precompiled.zip && \
    mkdir -p /opt/elixir-${ELIXIR_VERSION}/ && \
    unzip Precompiled.zip -d /opt/elixir-${ELIXIR_VERSION}/ && \
    rm Precompiled.zip && \
    apk --no-cache del build-dependencies 

RUN apk --no-cache add npm

ENV PATH $PATH:/opt/elixir-${ELIXIR_VERSION}/bin

RUN mix local.hex --force
RUN mix local.rebar --force

CMD ["/bin/ash"]
