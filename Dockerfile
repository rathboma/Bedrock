# syntax=docker/dockerfile:1.7

# ---- builder ----
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      clang-18 \
      libpcre2-dev \
      zlib1g-dev \
      git \
      ca-certificates \
      python3 \
      python-is-python3 \
      python3-jsonschema \
      python3-jinja2 \
    && rm -rf /var/lib/apt/lists/*

ENV CC=clang-18 \
    CXX=clang++-18

WORKDIR /src
COPY . .

# The workflow checks out with submodules:recursive, but re-init here so a
# plain `docker build` from a clean clone still works.
RUN git config --global --add safe.directory /src \
 && git submodule update --init --recursive \
 && make -j"$(nproc)" bedrock

# ---- runtime ----
FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      libpcre2-8-0 \
      zlib1g \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/bedrock /usr/local/bin/bedrock

RUN printf '#!/bin/sh\nset -e\nDB="${BEDROCK_DB:-/data/bedrock.db}"\nmkdir -p "$(dirname "$DB")"\ntouch "$DB"\nexec bedrock -db "$DB" -serverHost "0.0.0.0:8888" -nodeName "${BEDROCK_NODE_NAME:-bedrock}" -priority "${BEDROCK_PRIORITY:-200}" "$@"\n' > /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 8888

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
