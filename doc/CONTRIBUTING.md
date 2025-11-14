# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional
documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary
information to effectively respond to your bug report or contribution.


## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue, please check [existing open](https://github.com/aws-samples/amazon-eks-ami/issues), or [recently closed](https://github.com/aws-samples/amazon-eks-ami/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aclosed%20), issues to make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

* A reproducible test case or series of steps
* The version of our code being used
* Any modifications you've made relevant to the bug
* Anything unusual about your environment or deployment


## Contributing via Pull Requests
Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the *main* branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. Ensure your changes match our style guide (`make fmt`).
4. Ensure local tests pass (`make test`).
5. Commit to your fork using clear commit messages.
6. Send us a pull request, answering any default questions in the pull request interface.
7. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional document on [forking a repository](https://help.github.com/articles/fork-a-repo/) and
[creating a pull request](https://help.github.com/articles/creating-a-pull-request/).

### Testing Changes

When submitting PRs, we want to verify that there are no regressions in the AMI with the new changes. EKS runs various tests before publishing new Amazon EKS optimized Amazon Linux AMIs, which will ensure the highest level of confidence that there are no regressions in officially published AMIs. To maintain the health of this repo, we need to do some basic validation prior to merging PRs. Eventually, we hope to automate this process. Until then, here are the basic steps that we should take before merging PRs.

**Test #1: Verify that the unit tests pass**

Please add a test case for your changes, if possible. See the [unit test README](https://github.com/awslabs/amazon-eks-ami/tree/main/test#readme) for more information. These tests will be run automatically for every pull request.

```
make test
```

**Test #2: Verify that building AMIs still works**

If your change is relevant to a specific Kubernetes version, build all AMIs that apply. Otherwise, just choose the latest available Kubernetes version.

```
# Configure AWS credentials
make 1.22
```

**Test #3: Create a nodegroup with new AMI and confirm it joins a cluster**

Once the AMI is built, we need to verify that it can join a cluster. You can use `eksctl`, or your method of choice, to create a cluster and add nodes to it using the AMI you built. Below is an example config file.

`cluster.yaml`

```
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: basic-cluster
  region: us-west-2
  version: '1.22'

nodeGroups:
  - name: ng
    instanceType: m5.large
    ami: [INSERT_AMI_ID]
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh basic-cluster
```

Then run:

```
eksctl create cluster -f cluster.yaml
```

`eksctl` will verify that the nodes join the cluster before completing.

**Test #4: Verify that the nodes are Kubernetes conformant**

You can use [sonobuoy](https://sonobuoy.io/) to run conformance tests on the cluster you've create in *Test #2*. You should only include nodes with the custom AMI built in *Test #1*. You must install `sonobuoy` locally before running.

```
sonobuoy run --wait
```

By default, `sonobuoy` will run `e2e` and `systemd-logs`. This step may take multiple hours to run.

**Test #5: [Optional] Test your specific PR changes**

If your PR has changes that require additional, custom validation, provide the appropriate steps to verify that the changes don't cause regressions and behave as expected. Document the steps taken in the CR.

**Clean Up**

Delete the cluster:

```
eksctl delete cluster -f cluster.yaml
```

## Troubleshooting

**Tests fail with `realpath: command not found`**

When running `make test`, you may see a message like below:

```
test/test-harness.sh: line 41: realpath: command not found
/entrypoint.sh: line 13: /test.sh: No such file or directory
```

The issue is discussed in [this StackExchange post](https://unix.stackexchange.com/questions/101080/realpath-command-not-found).

On OSX, running `brew install coreutils` resolves the issue.

## Finding contributions to work on
Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels ((enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any ['help wanted'](https://github.com/aws-samples/amazon-eks-ami/labels/help%20wanted) issues is a great place to start.


## Code of Conduct
This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact
opensource-codeofconduct@amazon.com with any additional questions or comments.


## Security issue notifications
If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.


## Licensing

See the [LICENSE](https://github.com/aws-samples/amazon-eks-ami/blob/main/LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.

We may ask you to sign a [Contributor License Agreement (CLA)](http://en.wikipedia.org/wiki/Contributor_License_Agreement) for larger changes.
