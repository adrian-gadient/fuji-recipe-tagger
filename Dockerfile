FROM bats/bats:latest

# Install dependencies
RUN apk add --no-cache exiftool perl-image-exiftool miller \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing git

# Install Bats helpers to FIXED location
RUN mkdir -p /opt/bats-helpers && \
    git clone https://github.com/bats-core/bats-support.git /opt/bats-helpers/bats-support && \
    git clone https://github.com/bats-core/bats-assert.git /opt/bats-helpers/bats-assert && \
    git clone https://github.com/bats-core/bats-file.git /opt/bats-helpers/bats-file

WORKDIR /code

# COPY EVERYTHING - no volumes needed
COPY . /code/
RUN chmod +x *.sh tests/*.bats

# Default command runs all tests
CMD ["bats", "tests/*.bats"]
