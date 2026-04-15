# syntax=docker/dockerfile:1.7

# ---- downloader ----
FROM ubuntu:24.04 AS downloader

ARG BEDROCK_VERSION
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
    && rm -rf /var/lib/apt/lists/*

RUN test -n "${BEDROCK_VERSION}" \
 && curl -fsSL -o /bedrock \
      "https://github.com/Expensify/Bedrock/releases/download/${BEDROCK_VERSION}/bedrock" \
 && chmod +x /bedrock

# ---- runtime ----
FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      libpcre2-8-0 \
      zlib1g \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /bedrock /usr/local/bin/bedrock

RUN printf '#!/bin/sh\nset -e\nDB="${BEDROCK_DB:-/data/bedrock.db}"\nmkdir -p "$(dirname "$DB")"\ntouch "$DB"\nexec bedrock -db "$DB" -serverHost "0.0.0.0:8888" -nodeName "${BEDROCK_NODE_NAME:-bedrock}" -priority "${BEDROCK_PRIORITY:-200}" "$@"\n' > /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 8888

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
