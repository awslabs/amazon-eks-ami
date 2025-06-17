FROM golang:1.21 AS imds-mock-build
RUN go env -w GOPROXY=direct
RUN GOBIN=/bin go install github.com/aws/amazon-ec2-metadata-mock/cmd@v1.11.2
RUN mv /bin/cmd /imds-mock

FROM public.ecr.aws/amazonlinux/amazonlinux:2023
RUN dnf -y update && \
    dnf -y install systemd containerd jq python3 awscli && \
    dnf clean all
RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py
RUN pip install --user 'moto[server]'
# I know how this looks, but it lets us use moto with our mocked IMDS and for now the simplicity is worth the hack
RUN sed -i 's/= random_instance_id()/= "i-1234567890abcdef0"/g' $HOME/.local/lib/python*/site-packages/moto/ec2/models/instances.py
COPY --from=imds-mock-build /imds-mock /usr/local/bin/imds-mock
# The content of ec2 userdata in the 'aemm-default-config.json'
# file is the base64 encoding of a minimally viable NodeConfig.
# At the time of this change, it is equal to the following:
#
# ---
# apiVersion: node.eks.aws/v1alpha1
# kind: NodeConfig
# spec:
#   cluster:
#     name: my-cluster
#     apiServerEndpoint: https://example.com
#     certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
#     cidr: 10.100.0.0/16
COPY test/e2e/infra/aemm-default-config.json /etc/aemm-default-config.json
COPY test/e2e/infra/nvidia-ctk /usr/bin/nvidia-ctk
COPY test/e2e/infra/systemd/kubelet.service /usr/lib/systemd/system/kubelet.service
COPY test/e2e/infra/systemd/containerd.service /usr/lib/systemd/system/containerd.service
COPY test/e2e/infra/mock/ /sys_devices_system_mock/
COPY test/e2e/helpers.sh /helpers.sh

RUN mkdir -p /etc/eks/image-credential-provider/
RUN touch /etc/eks/image-credential-provider/ecr-credential-provider
ENV CPU_DIR /sys_devices_system_mock/cpu
ENV NODE_DIR /sys_devices_system_mock/node

ENTRYPOINT ["/usr/lib/systemd/systemd","--system"]
