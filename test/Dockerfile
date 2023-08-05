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
COPY boot/ /etc/eks/
COPY boot/containerd-config.toml boot/kubelet-containerd.service boot/pull-sandbox-image.sh boot/sandbox-image.service /etc/eks/containerd/
COPY boot/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
COPY boot/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
COPY boot/ecr-credential-provider-config.json /etc/eks/image-credential-provider/config.json
COPY test/entrypoint.sh /entrypoint.sh
COPY boot/bin/* /usr/bin/
COPY test/mocks/ /sbin/
ENTRYPOINT ["/entrypoint.sh"]
