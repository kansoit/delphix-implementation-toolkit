# syntax=docker/dockerfile:1

ARG NODE_IMAGE=node:current-bookworm-slim
FROM ${NODE_IMAGE} AS build

ARG KNAP_VERSION=latest
ARG NPM_VERSION=latest

WORKDIR /build/helper

# Build the frontend and install only the production dependencies. The full
# source tree exists only in this intermediate stage.
COPY delphix-masking-helper/ /build/helper/
RUN npm install --global "npm@${NPM_VERSION}" \
    && npm ci --omit=dev \
    && npm ci --prefix frontend \
    && npm run build --prefix frontend \
    && rm -rf frontend/node_modules \
    && mkdir -p /runtime/helper/frontend/src/lib /runtime/helper/java-runner /runtime/report \
    && cp server.js ai.js delphix.js package.json /runtime/helper/ \
    && cp -a node_modules classifiers presets lib /runtime/helper/ \
    && cp -a java-runner/AlgorithmRunner.jar /runtime/helper/java-runner/ \
    && cp -a frontend/dist /runtime/helper/frontend/ \
    && cp frontend/src/lib/framework-knowledge.en.json \
       /runtime/helper/frontend/src/lib/

COPY delphix_install_report/ /build/report-source/
RUN mkdir -p /runtime/report \
    && cp /build/report-source/cc_install_report*.py \
          /build/report-source/cc_install_report*.sh \
          /build/report-source/cc_install_report_*.md \
          /runtime/report/

FROM ${NODE_IMAGE}

ARG KNAP_VERSION=latest
ARG NPM_VERSION=latest

ENV HOME=/home/delphix \
    DCT_TOOLKIT_BIN=/home/delphix/.local/bin/dct-toolkit \
    PATH=/home/delphix/.local/bin:/home/delphix/bin:$PATH \
    NPM_CONFIG_PREFIX=/usr/local \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_PROGRESS=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NODE_ENV=production \
    PORT=3000

RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
       bash ca-certificates jq openjdk-17-jre-headless python3 tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash --user-group delphix \
    && mkdir -p /home/delphix/.local/bin /home/delphix/.config /home/delphix/reports \
    && npm install --global "npm@${NPM_VERSION}" \
    && npm install --global "knap@${KNAP_VERSION}" \
    && rm -rf /root/.npm

WORKDIR /opt/delphix-masking-helper

# Only the runtime subset is copied from the build stage.
COPY --from=build /runtime/helper/ /opt/delphix-masking-helper/
COPY --from=build /runtime/report/ /home/delphix/.local/bin/
COPY dct-toolkit /home/delphix/.local/bin/dct-toolkit

RUN chmod 0755 /home/delphix/.local/bin/dct-toolkit \
    && mkdir -p db test-files \
    && ln -s /home/delphix/.local/bin/cc_install_report.py \
       /home/delphix/.local/bin/cc-install-report \
    && ln -s /home/delphix/.local/bin/cc_install_report_fetch.py \
       /home/delphix/.local/bin/cc-install-report-fetch \
    && ln -s /home/delphix/.local/bin/cc_install_report_render.py \
       /home/delphix/.local/bin/cc-install-report-render \
    && rm -f db/*.db db/*.db-shm db/*.db-wal \
    && chown -R delphix:delphix \
       /opt/delphix-masking-helper /home/delphix

USER delphix
WORKDIR /home/delphix

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "/opt/delphix-masking-helper/server.js"]
