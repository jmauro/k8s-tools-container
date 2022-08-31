# AWS CLI
ARG AWSIMAGE_VERSION="latest"

# K8S
ARG KUBECTL_VERSION="v1.20.0"
ARG KREW_ROOT="/usr/local/krew"
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

# K9s
ARG K9S_VERSION="v0.26.3"

# FZF
ARG FZF_VERSION="0.33.0"

# Direnv
ARG bin_path="/usr/local/bin"

#================
# The build image
#================
# Setup the build environment:
FROM amazon/aws-cli:${AWSIMAGE_VERSION} AS build

# Global ENV
ARG KUBECTL_VERSION
ARG YQ_VERSION
ARG K9S_VERSION
ARG FZF_VERSION

ARG KUBECTL_PLUGINS
ARG KREW_ROOT
ARG bin_path

# ENV for build image
ENV OS="linux" \
    ARCH="amd64"
ENV ENV_KUBECTL_VERSION=${KUBECTL_VERSION}
ENV ENV_YQ_VERSION=${YQ_VERSION}
ENV ENV_K9S_VERSION=${K9S_VERSION}
ENV ENV_FZF_VERSION=${FZF_VERSION}
ENV KREW_ROOT=${KREW_ROOT}
ENV bin_path=${bin_path}

RUN yum install -y git tar gzip coreutils curl awk golang make wget

# GET ALL BINARIES:
# -----------------
WORKDIR /tmp
RUN mkdir -p /etc/env.d
# AWSCLI
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && VERSION=\"$(aws --version | awk '{ print $1}' | cut -d/ -f 2)\" \
  && printf 'export AWCLI_VERSION=%s' \"${VERSION}\" | tee /etc/env.d/awscli.env" ]

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl ${bin_path}/
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && VERSION=\"$(aws --version | awk '{ print $1}' | cut -d/ -f 2)\" \
  && printf 'export KUBECTL_VERSION=%s' \"${ENV_KUBECTL_VERSION}\" | tee /etc/env.d/kubectl.env" ]

# Install krew
RUN set -x \
  && KREW="krew-${OS}_${ARCH}" \
  && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" \
  && tar zxvf "${KREW}.tar.gz" \
  && ./"${KREW}" install ${KUBECTL_PLUGINS}
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && echo \"export KREW_VERSION=\"$(kubectl krew version | grep GitTag | awk  '{ print $NF}')\"\" | tee /etc/env.d/krew.env" ]

# WORKAROUND: doctor plugin not to the latest version in the store
# Ref: https://github.com/emirozer/kubectl-doctor/issues/22
RUN curl -fsSLO -o "kubectl-doctor" "https://github.com/emirozer/kubectl-doctor/releases/download/0.3.1/kubectl-doctor_linux_amd64" \
  && chmod +x kubectl-doctor \
  && mv kubectl-doctor /usr/local/krew/store/doctor/v0.3.0/

# Install yq
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && YQ=yq_${OS}_${ARCH} \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ} \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums_hashes_order \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums \
  && curl -fsSLO https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/extract-checksum.sh \
  && bash -x ./extract-checksum.sh SHA-256 ${YQ} | awk '{ print $2 \" \" $1}' | sha256sum -c - \
  && chmod +x ${YQ} \
  && mv ${YQ} ${bin_path}/yq" ]
RUN echo "export YQ_VERSION=${ENV_YQ_VERSION}" | tee /etc/env.d/yq.env

# Install k9s
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && K9S_TAR=k9s_Linux_x86_64.tar.gz \
  && curl -fsSLO https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_x86_64.tar.gz \
  && curl -fsSLO https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.txt \
  && grep -i ${K9S_TAR} checksums.txt | sha256sum -c - \
  && tar vxfz ${K9S_TAR} \
  && mv k9s ${bin_path}/" ]
RUN echo "export K9S_VERSION=${ENV_K9S_VERSION}" | tee /etc/env.d/k9s.env

# Install fzf
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && FZF=fzf-${FZF_VERSION}-${OS}_${ARCH}.tar.gz \
  && curl -fsSLO https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/${FZF} \
  && curl -fsSLO https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf_${FZF_VERSION}_checksums.txt \
  && grep -i ${FZF} fzf_${FZF_VERSION}_checksums.txt | sha256sum -c - \
  && tar vxfz ${FZF} \
  && mv fzf ${bin_path}" ]
RUN echo "export FZF_VERSION=${ENV_FZF_VERSION}" | tee /etc/env.d/fzf.env

# Install direnv
RUN ["/bin/bash", "-xc", "set -o pipefail \
  && curl -sfL https://direnv.net/install.sh | bash" ]
RUN echo "export DIRENV_VERSION=\"$(direnv version)\""

#================
# The final image
#================
FROM amazon/aws-cli:${AWSIMAGE_VERSION}

# Global ENV
ARG KUBECTL_VERSION
ARG YQ_VERSION
ARG K9S_VERSION

ARG KUBECTL_PLUGINS
ARG KREW_ROOT
ARG bin_path

# To make sure the KREW_ROOT is set correctly
ENV KREW_ROOT=${KREW_ROOT}
ENV PATH=${KREW_ROOT}/bin:${PATH}

COPY --from=build /etc/env.d /etc/env.d

WORKDIR /root
# Install kubectl
COPY --from=build ${bin_path}/kubectl ${bin_path}/kubectl
# Install krew
COPY --from=build ${KREW_ROOT} ${KREW_ROOT}
# Install yq
COPY --from=build ${bin_path}/yq ${bin_path}/yq
# Install k9s
COPY --from=build ${bin_path}/k9s ${bin_path}/k9s
# Install direnv
COPY --from=build ${bin_path}/direnv ${bin_path}/direnv
# Install fzf
COPY --from=build ${bin_path}/fzf ${bin_path}/fzf

COPY scripts/yum_install.sh /usr/bin/yum_install
RUN chmod +x /usr/bin/yum_install

RUN yum_install bash-completion tmux jq file git tar gzip wget curl
RUN curl https://raw.githubusercontent.com/jonmosco/kube-ps1/master/kube-ps1.sh -o /etc/profile.d/kube-ps1.sh

COPY bashrc /root/.bashrc

# Could use systemd + exec
ENTRYPOINT ["/bin/bash", "-c", "/bin/bash -l"]
