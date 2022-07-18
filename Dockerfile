FROM amazon/aws-cli:latest AS git
# Install kube plugins
RUN yum install -y git

RUN git clone https://github.com/ahmetb/kubectx /opt/kubectx

FROM amazon/aws-cli:latest AS aws-cli

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

COPY --from=git /opt/kubectx /opt/kubectx

RUN ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx &&  ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["aws"]
