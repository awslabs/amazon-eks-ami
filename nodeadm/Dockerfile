# shim to help build project in a containerized fashion on kaniko
#
# usage: (run on top of the repository)
# ```
# docker run \
#   --rm \
#   -v $(pwd):/workspace \
#   gcr.io/kaniko-project/executor:latest \
#   --dockerfile /workspace/Dockerfile \
#   --context dir:///workspace/ \
#   --no-push
# ```

FROM public.ecr.aws/eks-distro-build-tooling/golang:1.21

WORKDIR /workspace

# satisfy errors: fatal: detected dubious ownership in repository at '/workspace'
RUN git config --global --add safe.directory '/workspace'
RUN make
