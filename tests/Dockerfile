FROM public.ecr.aws/amazonlinux/amazonlinux:2

ENV IMDS_HOST=127.0.0.1:1338

COPY files/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
COPY files/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
COPY tests/entrypoint.sh /entrypoint.sh
COPY files /etc/eks
COPY tests/mocks/ /sbin/

RUN yum install -y jq
RUN /sbin/install-imds

ENTRYPOINT ["/entrypoint.sh"]
