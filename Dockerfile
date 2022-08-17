# AWS CLI
ARG AWSCLI_VERSION="latest"

# K8S
ARG KUBECTL_VERSION="v1.20.0"
ARG BIN_KUBECTL="/usr/local/bin/kubectl"
ARG BIN_KREW="/usr/local/krew"
# Plugins list:
# - krew: core plug in manager
# - ctx: switch between contexts (clusters) (ref: https://github.com/ahmetb/kubectx)
# - ns: switch between Kubernetes namespaces (ref: https://github.com/ahmetb/kubectx)
# - doctor: scan your k8s cluster to see if there are anomalies or useful action points (ref: https://github.com/emirozer/kubectl-doctor)
# - ketall: show really all k8s resources (ref: https://github.com/corneliusweig/ketall)
# - images: Show container images used in the cluster (ref: https://github.com/chenjiandongx/kubectl-images)
ARG KUBECTL_PLUGINS="krew ctx ns doctor get-all images"

# YQ
ARG YQ_VERSION="v4.27.2"
ARG BIN_YQ="/usr/local/bin/yq"

# K9s
ARG K9S_VERSION="v0.26.3"
ARG BIN_K9S="/usr/local/bin/k9s"

#================
# The build image
#================
# Setup the build environment:
FROM amazon/aws-cli:${AWSCLI_VERSION} AS build

# Global ENV
ARG AWSCLI_VERSION
ARG KUBECTL_VERSION
ARG YQ_VERSION
ARG K9S_VERSION

ARG KUBECTL_PLUGINS
ARG BIN_KUBECTL
ARG BIN_KREW
ARG BIN_YQ
ARG BIN_K9S


# ENV for build image
ENV OS="linux" \
    ARCH="amd64"
ENV ENV_AWSCLI_VERSION=${AWSCLI_VERSION}
ENV ENV_KUBECTL_VERSION=${KUBECTL_VERSION}
ENV ENV_YQ_VERSION=${YQ_VERSION}
ENV ENV_K9S_VERSION=${K9S_VERSION}

RUN yum install -y git tar gzip coreutils curl awk golang make

# GET ALL BINARIES:
# -----------------
WORKDIR /tmp

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl ${BIN_KUBECTL}

# Install krew
RUN set -x \
  && KREW="krew-${OS}_${ARCH}" \
  && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" \
  && tar zxvf "${KREW}.tar.gz" \
  && KREW_ROOT=${BIN_KREW} ./"${KREW}" install ${KUBECTL_PLUGINS}

# Install yq
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && YQ=yq_${OS}_${ARCH} \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ} \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums_hashes_order \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/extract-checksum.sh \
  && bash -x ./extract-checksum.sh SHA-256 ${YQ} | awk '{ print $2 \" \" $1}' | sha256sum -c - \
  && chmod +x ${YQ} \
  && mv ${YQ} ${BIN_YQ}" ]

# Install k9s
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && K9S_TAR=k9s_Linux_x86_64.tar.gz \
  && curl -fsSLO https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_x86_64.tar.gz \
  && curl -fsSLO https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.txt \
  && grep -i ${K9S_TAR} checksums.txt | sha256sum -c - \
  && tar vxfz ${K9S_TAR} \
  && mv k9s ${BIN_K9S}" ]

#================
# The final image
#================
FROM amazon/aws-cli:${AWSCLI_VERSION}

# Global ENV
#ARG AWSCLI_VERSION
ARG KUBECTL_VERSION
ARG YQ_VERSION
ARG K9S_VERSION

ARG KUBECTL_PLUGINS
ARG BIN_KUBECTL
ARG BIN_KREW
ARG BIN_YQ
ARG BIN_K9S

WORKDIR /root
# Install kubectl
COPY --from=build ${BIN_KUBECTL} ${BIN_KUBECTL}
# Install krew
COPY --from=build ${BIN_KREW} ${BIN_KREW}
# Install yq
COPY --from=build ${BIN_YQ} ${BIN_YQ}
# INstall k9s
COPY --from=build ${BIN_K9S} ${BIN_K9S}

COPY scripts/yum_install.sh /usr/bin/yum_install
RUN chmod +x /usr/bin/yum_install

RUN yum_install bash-completion tmux jq file

COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["aws"]
