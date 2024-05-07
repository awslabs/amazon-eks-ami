## Tests

This directory contains a Dockerfile that is able to be used locally to test the `/etc/eks/boostrap.sh` script without having to use a real AL2 EC2 instance for a quick dev-loop. It is still necessary to test the bootstrap script on a real instance since the Docker image is not a fully accurate representation.

## AL2 EKS Optimized AMI Docker Image

The image is built using the official AL2 image `public.ecr.aws/amazonlinux/amazonlinux:2`. It has several mocks installed including the [ec2-metadata-mock](https://github.com/aws/amazon-ec2-metadata-mock). Mocks are installed into `/sbin`, so adding addditional ones as necessary should be as simple as dropping a bash script in the `mocks` dir named as the command you would like to mock out.

## Usage

```bash

## The docker context needs to be at the root of the repo
docker build -t eks-optimized-ami -f Dockerfile ../

docker run -it eks-optimized-ami /etc/eks/bootstrap.sh --b64-cluster-ca dGVzdA== --apiserver-endpoint http://my-api-endpoint test
```

The `test-harness.sh` script wraps a build and runs test script in the `cases` dir. Tests scripts within the `cases` dir are invoked by the `test-harness.sh` script and have access to the `run` function. The `run` function accepts a temporary directory as an argument in order to mount as a volume in the container so that test scripts can check files within the `/etc/kubernetes/` directory after a bootstrap run. The remaining arguments to the `run` function are a path to a script within the AL2 EKS Optimized AMI Docker Container.

Here's an example `run` call:

```
run ${TEMP_DIR} /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv4 \
    --dns-cluster-ip 192.168.0.1 \
    test-cluster-name
```

## ECR Public

You may need to logout of ECR public or reauthenticate if your credentials are expired:

```bash
docker logout public.ecr.aws
```

ECR public allow anonymous access, but you cannot have expired credentials loaded.