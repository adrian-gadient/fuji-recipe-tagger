FROM bats/bats:latest

# Install dependencies
RUN apk add --no-cache \
    exiftool \
    perl-image-exiftool \
    miller --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing

WORKDIR /code
