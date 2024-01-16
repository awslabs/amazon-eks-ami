FROM golang:1.21 AS imds-mock-build
RUN go env -w GOPROXY=direct
RUN GOBIN=/bin go install github.com/aws/amazon-ec2-metadata-mock/cmd@v1.11.2
RUN mv /bin/cmd /imds-mock

FROM golang:1.21 AS nodeadm-build
WORKDIR /go/src/github.com/awslabs/amazon-eks-ami/nodeadm
RUN go env -w GOPROXY=direct
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY Makefile .
COPY . .
RUN make build
RUN mv _bin/nodeadm /nodeadm

FROM amazonlinux:2023
RUN dnf -y update && \
    dnf -y install systemd containerd && \
    dnf clean all
COPY --from=imds-mock-build /imds-mock /usr/local/bin/imds-mock
COPY --from=nodeadm-build /nodeadm /usr/local/bin/nodeadm
COPY test/e2e/infra/systemd/imds-mock.service /usr/lib/systemd/system/imds-mock.service
RUN systemctl enable imds-mock.service
COPY test/e2e/infra/systemd/kubelet.service /usr/lib/systemd/system/kubelet.service
COPY test/e2e/infra/systemd/containerd.service /usr/lib/systemd/system/containerd.service
COPY test/e2e/helpers.sh /helpers.sh
ENTRYPOINT ["/usr/lib/systemd/systemd","--system"]
