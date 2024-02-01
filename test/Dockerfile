FROM public.ecr.aws/aws-ec2/amazon-ec2-metadata-mock:v1.11.2 as aemm
FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN amazon-linux-extras enable docker && \
    yum install -y jq containerd wget which && \
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod a+x /usr/local/bin/yq

ENV IMDS_ENDPOINT=127.0.0.1:1338
COPY --from=aemm /ec2-metadata-mock /sbin/ec2-metadata-mock
RUN mkdir -p /etc/systemd/system
RUN mkdir -p /etc/eks/containerd
COPY files/ /etc/eks/
COPY files/containerd-config.toml files/kubelet-containerd.service files/pull-sandbox-image.sh files/sandbox-image.service /etc/eks/containerd/
COPY files/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
COPY files/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
COPY files/ecr-credential-provider-config.json /etc/eks/image-credential-provider/config.json
COPY test/entrypoint.sh /entrypoint.sh
COPY files/bin/* /usr/bin/
COPY test/mocks/ /sbin/
ENTRYPOINT ["/entrypoint.sh"]
