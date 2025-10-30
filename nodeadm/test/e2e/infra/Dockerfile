FROM golang:1.21 AS imds-mock-build
RUN go env -w GOPROXY=direct
RUN GOBIN=/bin go install github.com/aws/amazon-ec2-metadata-mock/cmd@v1.11.2
RUN mv /bin/cmd /imds-mock

FROM public.ecr.aws/amazonlinux/amazonlinux:2023
ARG CONTAINERD_VERSION
RUN yum install -y --allowerasing curl && yum clean all
RUN dnf -y update && \
    dnf -y install systemd jq python3 awscli nmap-ncat iptables tar procps && \
    dnf clean all
# TO-DO: install containerd v2 from AL repo as well once it is available
RUN if [[ "$CONTAINERD_VERSION" == *".*" ]]; then \
        dnf install -y containerd-${CONTAINERD_VERSION}; \
    else \
        curl -L -o /tmp/containerd.tar.gz https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz && \
        mkdir -p /tmp/containerd && \
        tar -C /tmp/containerd -xzf /tmp/containerd.tar.gz && \
        cp /tmp/containerd/bin/* /usr/local/bin/ && \
        rm -rf /tmp/containerd /tmp/containerd.tar.gz; \
    fi
RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py
COPY test/e2e/infra/requirements.txt /
RUN pip install --user -r requirements.txt
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
COPY test/e2e/infra/mock/system/ /
COPY test/e2e/infra/proxy.py /proxy.py

RUN mkdir -p /etc/eks/image-credential-provider/
RUN touch /etc/eks/image-credential-provider/ecr-credential-provider
ENV CPU_DIR /sys_devices_system_mock/cpu
ENV NODE_DIR /sys_devices_system_mock/node

RUN mkdir -p /mock/bin
ENV PATH "/mock/bin/:$PATH"

ENTRYPOINT ["/usr/lib/systemd/systemd","--system"]
