FROM bats/bats:latest

# Install system dependencies
RUN apk add --no-cache \
    exiftool \
    perl-image-exiftool \
    miller --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    git

# Install bats helper libraries to /opt instead of /usr/lib
RUN mkdir -p /opt/bats-helpers && \
    git clone https://github.com/bats-core/bats-support.git /opt/bats-helpers/bats-support && \
    git clone https://github.com/bats-core/bats-assert.git /opt/bats-helpers/bats-assert && \
    git clone https://github.com/bats-core/bats-file.git /opt/bats-helpers/bats-file

WORKDIR /code