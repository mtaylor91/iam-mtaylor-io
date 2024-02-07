FROM images.home.mtaylor.io/haskell:latest AS dependencies
# Install system dependencies
USER root
RUN apt-get update && apt-get install -y zlib1g-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
# Add metadata files and build dependencies
USER build
ADD --chown=build:build package.yaml package.yaml
ADD --chown=build:build stack.yaml stack.yaml
ADD --chown=build:build stack.yaml.lock stack.yaml.lock
RUN stack build --only-dependencies --system-ghc


FROM images.home.mtaylor.io/haskell:latest AS build
# Install system dependencies
USER root
RUN apt-get update && apt-get install -y zlib1g-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
# Add the source code and build
USER build
COPY --from=dependencies /build/.stack /build/.stack
ADD --chown=build:build . .
RUN stack build --system-ghc --copy-bins


FROM images.home.mtaylor.io/base:latest AS runtime
# Install system dependencies
USER root
RUN apt-get update && apt-get install -y zlib1g \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
# Copy the built executables
COPY --from=build /build/.local/bin/api-mtaylor-io /usr/local/bin/api-mtaylor-io
# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/api-mtaylor-io"]