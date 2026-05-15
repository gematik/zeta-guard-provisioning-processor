FROM docker.io/alpine:3.23.3

RUN apk add \
    bash \
    cabextract \
    cosign \
    jq \
    libxslt \
    openssl

ENV TOOLS_PATH=/opt/provisioning-tools
ENV PROCESSORS_PATH="$TOOLS_PATH/processors"
ADD src $TOOLS_PATH

RUN apk update && apk upgrade

USER 1000

ENTRYPOINT [ "/opt/provisioning-tools/process-provisioned-files.sh" ]
