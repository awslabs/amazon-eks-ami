FROM public.ecr.aws/aws-ec2/amazon-ec2-metadata-mock:v1.11.2 as aemm
FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN yum install -y jq

ENV IMDS_ENDPOINT=127.0.0.1:1338
COPY --from=aemm /ec2-metadata-mock /sbin/ec2-metadata-mock
COPY files/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
COPY files/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
COPY test/entrypoint.sh /entrypoint.sh
COPY files /etc/eks
COPY files/bin/* /usr/bin/
COPY test/mocks/ /sbin/
ENTRYPOINT ["/entrypoint.sh"]
