# AWS CLI
ARG AWSIMAGE_VERSION="latest"

# K8S
ARG KUBECTL_VERSION="v1.26.6"
ARG KREW_ROOT="/usr/local/krew"
# Plugins list:
# - krew: core plug in manager
# - ctx: switch between contexts (clusters) (ref: https://github.com/ahmetb/kubectx)
# - ns: switch between Kubernetes namespaces (ref: https://github.com/ahmetb/kubectx)
# - doctor: scan your k8s cluster to see if there are anomalies or useful action points (ref: https://github.com/emirozer/kubectl-doctor)
# - ketall: show really all k8s resources (ref: https://github.com/corneliusweig/ketall)
# - images: Show container images used in the cluster (ref: https://github.com/chenjiandongx/kubectl-images)
ARG KUBECTL_PLUGINS="krew ctx ns doctor get-all images view-utilization ingress-nginx explore mtail"

# YQ
ARG YQ_VERSION="v4.34.2"

# K9s
ARG K9S_VERSION="v0.27.4"

# FZF
ARG FZF_VERSION="0.42.0"

# Direnv
ARG bin_path="/usr/local/bin"

# Helm
ARG HELM_VERSION="v3.12.2"

# Velero
ARG VELERO_VERSION="v1.9.4"

# Vault
ARG VAULT_VERSION="1.13.2"

# Eksctl
ARG EKSCTL_VERSION="v0.150.0"

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
ARG HELM_VERSION
ARG VELERO_VERSION
ARG VAULT_VERSION
ARG EKSCTL_VERSION

ARG KUBECTL_PLUGINS
ARG KREW_ROOT
ARG bin_path

# ENV for build image
ENV OS="linux" \
    ARCH="amd64"
ENV KREW_ROOT=${KREW_ROOT}
ENV PATH=${KREW_ROOT}/bin:${PATH}
ENV bin_path=${bin_path}

# Build container so don't need to clean it
# hadolint ignore=DL3032,DL3033
RUN yum install -y git tar gzip coreutils curl awk golang make wget unzip

# GET ALL BINARIES:
# -----------------
WORKDIR /tmp
SHELL ["/bin/bash", "-o", "pipefail", "-o", "xtrace", "-c"]

# Install Latest openssl
RUN git clone https://github.com/openssl/openssl.git
WORKDIR /tmp/openssl

# hadolint ignore=DL3032,DL3033
RUN yum install -y make gcc perl-CPAN.noarch perl-IPC-Run.noarch perl-IPC-Cmd.noarch
RUN ./Configure \
  && make -j "$(nproc)"\
  && make -j "$(nproc)" install

WORKDIR /etc/env.d
WORKDIR /tmp
# AWSCLI
RUN  VERSION=\"$(aws --version | awk '{ print $1}' | cut -d/ -f 2)\" \
  && printf 'export AWSCLI_VERSION=%s\n' "${VERSION}" | tee /etc/env.d/awscli.env

# Install kubectl
RUN curl --fail --silent --show-error --location --remote-name "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  && chmod +x ./kubectl \
  && mv ./kubectl ${bin_path}/ \
  && printf 'export KUBECTL_VERSION=%s\n' "${KUBECTL_VERSION}" | tee /etc/env.d/kubectl.env

# Install krew
RUN set -x \
  && KREW="krew-${OS}_${ARCH}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" \
  && tar zxvf "${KREW}.tar.gz" \
  && ./"${KREW}" install ${KUBECTL_PLUGINS} \
  && echo "export KREW_VERSION=\"$(kubectl krew version | grep GitTag | awk  '{ print $NF}')\"" | tee /etc/env.d/krew.env

# WORKAROUND: doctor plugin not to the latest version in the store
# Ref: https://github.com/emirozer/kubectl-doctor/issues/22
RUN DOCTOR="kubectl-doctor_${OS}_${ARCH}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/emirozer/kubectl-doctor/releases/download/0.3.1/${DOCTOR}" \
  && chmod +x ${DOCTOR} \
  && mv ${DOCTOR} /usr/local/krew/store/doctor/v0.3.0/kubectl-doctor

# Install yq
RUN YQ="yq_${OS}_${ARCH}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums_hashes_order" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/extract-checksum.sh" \
  && bash -x ./extract-checksum.sh SHA-256 ${YQ} | awk '{ print $2 " " $1}' | sha256sum -c - \
  && chmod +x ${YQ} \
  && mv ${YQ} ${bin_path}/yq \
  && echo "export YQ_VERSION=${YQ_VERSION}" | tee /etc/env.d/yq.env

# Install k9s
RUN K9S_TAR="k9s_Linux_${ARCH}.tar.gz" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/${K9S_TAR}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.txt" \
  && grep -i ${K9S_TAR} checksums.txt | sha256sum -c - \
  && tar vxfz ${K9S_TAR} \
  && mv k9s ${bin_path}/ \
  && echo "export K9S_VERSION=${K9S_VERSION}" | tee /etc/env.d/k9s.env

# Install fzf
RUN FZF="fzf-${FZF_VERSION}-${OS}_${ARCH}.tar.gz" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/${FZF}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf_${FZF_VERSION}_checksums.txt" \
  && grep -i ${FZF} fzf_${FZF_VERSION}_checksums.txt | sha256sum -c - \
  && tar vxfz ${FZF} \
  && mv fzf ${bin_path} \
  && echo "export FZF_VERSION=${FZF_VERSION}" | tee /etc/env.d/fzf.env

# install Helm
RUN HELM="helm-${HELM_VERSION}-${OS}-${ARCH}" \
  && curl --fail --silent --show-error --location --remote-name "https://get.helm.sh/${HELM}.tar.gz" \
  && curl --fail --silent --show-error --location --remote-name "https://get.helm.sh/${HELM}.tar.gz.sha256sum" \
  && grep -i "${HELM}" ${HELM}.tar.gz.sha256sum | sha256sum -c - \
  && tar vxfz "${HELM}.tar.gz" \
  && mv "linux-amd64/helm" "${bin_path}/helm" \
  && echo "export HELM_VERSION=\"${HELM_VERSION}\"" | tee /etc/env.d/helm.env

# install velero
RUN VELERO="velero-${VELERO_VERSION}-${OS}-${ARCH}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/${VELERO}.tar.gz" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/CHECKSUM" \
  && grep -i "${VELERO}" CHECKSUM | sha256sum -c - \
  && tar vxfz "${VELERO}.tar.gz" \
  && mv "${VELERO}/velero" "${bin_path}/velero" \
  && echo "export VELERO_VERSION=\"${VELERO_VERSION}\"" | tee /etc/env.d/velero.env

# Install Vault
RUN VAULT="vault_${VAULT_VERSION}_${OS}_${ARCH}.zip" \
  && curl --fail --silent --show-error --location --remote-name "https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT}" \
  && curl --fail --silent --show-error --location --remote-name "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS" \
  && grep -i ${VAULT} "vault_${VAULT_VERSION}_SHA256SUMS" | sha256sum -c - \
  && unzip "${VAULT}" \
  && mv vault ${bin_path} \
  && echo "export VAULT_VERSION=${VAULT_VERSION}" | tee /etc/env.d/vault.env

# Install eksctl
RUN EKSCTL="eksctl_Linux_${ARCH}.tar.gz" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VERSION}/${EKSCTL}" \
  && curl --fail --silent --show-error --location --remote-name "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VERSION}/eksctl_checksums.txt" \
  && grep -i ${EKSCTL} eksctl_checksums.txt | sha256sum -c - \
  && tar -xzf "${EKSCTL}" \
  && mv eksctl ${bin_path} \
  && echo "export EKSCTL_VERSION=${EKSCTL_VERSION}" | tee /etc/env.d/eksctl.env

# Install direnv
RUN curl --fail --silent --location https://direnv.net/install.sh | bash \
  && echo "export DIRENV_VERSION=\"$(direnv version)\"" | tee /etc/env.d/direnv.env


#================
# The final image
#================
FROM amazon/aws-cli:${AWSIMAGE_VERSION}

# Global ENV
ARG KREW_ROOT
ARG bin_path
ARG HISHTORY_KEY

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
# Install helm
COPY --from=build ${bin_path}/helm ${bin_path}/helm
# Install velero
COPY --from=build ${bin_path}/velero ${bin_path}/velero
# Install vault
COPY --from=build ${bin_path}/vault ${bin_path}/vault
# Install vault
COPY --from=build ${bin_path}/eksctl ${bin_path}/eksctl
# Install openssl
COPY --from=build /usr/local/bin/openssl /usr/local/bin
COPY --from=build /usr/local/bin/c_rehash /usr/local/bin
COPY --from=build /usr/local/ssl /usr/local/lib64
COPY --from=build /usr/local/lib64 /usr/local/lib64
COPY --from=build /usr/local/include/openssl /usr/local/include

COPY scripts/yum_install.sh /usr/bin/yum_install
RUN chmod +x /usr/bin/yum_install

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Configure openssl
RUN echo '/usr/local/lib64' | tee /etc/ld.so.conf.d/lib.conf \
  && ldconfig

RUN yum_install amazon-linux-extras bash-completion tmux jq file git tar gzip wget curl vim \
  && amazon-linux-extras enable python3.8 \
  && yum_install python3.8 \
  && ln -sf /usr/bin/python3.8 /usr/bin/python3 \
  && ln -sf /usr/bin/pip-3.8 /usr/bin/pip3 \
  && curl -o "/etc/profile.d/kube-ps1.sh"  "https://raw.githubusercontent.com/jonmosco/kube-ps1/master/kube-ps1.sh" \
  && ${bin_path}/kubectl completion bash > /etc/profile.d/kubectl.sh \
  && sed -i -e 's/\(.*\)__start_kubectl kubectl/\1__start_kubectl kubectl\n\1__start_kubectl k/g' /etc/profile.d/kubectl.sh \
  && curl -o "/etc/profile.d/fzf.sh" "https://raw.githubusercontent.com/junegunn/fzf/master/shell/completion.bash"

# hishtory
RUN curl --fail --silent --show-error --location --remote-name "https://github.com/ddworken/hishtory/releases/download/v0.188/hishtory-linux-amd64" \
  && chmod +x hishtory-linux-amd64 \
  && ./hishtory-linux-amd64 install \
  echo 'y' | /root/.hishtory/hishtory init "${HISHTORY_KEY}" \
  && ./hishtory-linux-amd64 config-set filter-duplicate-commands true \
  && rm -rfv ./hishtory-linux-amd64

# -- [ Final Env
ENV KUBE_PS1_SYMBOL_ENABLE=false
ENV PS1='[\u@\h $(kube_ps1)] \w \$ '
ENV EDITOR=vim

# --[ dotfiles
COPY bashrc /root/.bashrc

# Could use systemd + exec
ENTRYPOINT ["/bin/bash"]
