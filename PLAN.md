### Goal

The goal of this plan is to move the `amazon-eks-ami` package from Amazon Web Services - Labs to Amazon Web Services. EKS and EKS customers depend on this package to build and vend AMIs used in production, and while EKS does test the AMIs before releasing, we'd like to enable more rigorous testing and provide customers more visibility into the process AMIs go through before releasing.

To achieve the higher level goal of moving the project to an AWS project, here are the following goals:

1. As much as possible, move all scripts, processes, etc. to the open by including maintaining all related scripts in a GitHub repo and using common tools for testing and releasing OSS software.
1. Implement processes that enable timely support for issues and PRs
1. Improve the safety and reliablity of releases by improving testing

### Stage 1: Improve GitHub Repo Hygiene

1. Create GitHub project board for tracking progress on current stage
1. Create GitHub project roadmap, similar to [this one](https://github.com/aws/aws-controllers-k8s/projects/1)
1. Triage 100% of current GitHub issues and set SLA to 3 days going forward
1. Review 100% of current PRs and set SLA to 3 days going forward for initial review
1. Update README.md so that customers are comfortable building AMIs, understand how it works and know how to test custom AMIs manually

### Stage 2: Improve Safety and Reliability

1. Build AMIs as part of PR process
1. Enable running Kubernetes conformance tests (or similar) with built AMIs
1. Enable adding additional tests to validate built AMIs
1. Run end-to-end tests are part of the PR process
1. All EKS Linux AMIs can be built from GitHub repo, including ARM, GPU, Bottlerocket, etc.

### Stage 3: Productionalize Release Process

1. Customers have some visibility into releases and the release process
1. New AMIs are built and released from the GitHub repo automatically, either on a schedule or after PRs are merged
