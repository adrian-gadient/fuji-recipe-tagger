# Run in Terminal: docker compose build
# Or build completely new: docker compose build --no-cache 

FROM bats/bats:latest

# Install dependencies
RUN apk add --no-cache exiftool perl-image-exiftool miller \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing git

# Install Bats helpers
RUN mkdir -p /opt/bats-helpers && \
    git clone https://github.com/bats-core/bats-support.git /opt/bats-helpers/bats-support && \
    git clone https://github.com/bats-core/bats-assert.git /opt/bats-helpers/bats-assert && \
    git clone https://github.com/bats-core/bats-file.git /opt/bats-helpers/bats-file

WORKDIR /code

# Copy project files
COPY . /code/

# Make scripts executable
RUN find /code/scripts -name "*.sh" -exec chmod +x {} \; && \
    find /code/tests -name "*.bats" -exec chmod +x {} \;

# Run tests by default
CMD ["bats", "/code/tests/"]