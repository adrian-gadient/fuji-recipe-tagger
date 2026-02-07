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

# Create symlinks to helpers DURING BUILD
RUN mkdir -p /code/tests/test_helper && \
    ln -s /opt/bats-helpers/bats-support /code/tests/test_helper/bats-support && \
    ln -s /opt/bats-helpers/bats-assert /code/tests/test_helper/bats-assert && \
    ln -s /opt/bats-helpers/bats-file /code/tests/test_helper/bats-file

# Make scripts executable (fix the path!)
RUN find /code/scripts -name "*.sh" -exec chmod +x {} \; && \
    find /code/tests -name "*.bats" -exec chmod +x {} \;

# Run tests by default
CMD ["bats", "/code/tests/"]