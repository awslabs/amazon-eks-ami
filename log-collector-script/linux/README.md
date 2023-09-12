### EKS Logs Collector (Linux)

This project was created to collect Amazon EKS log files and OS logs for troubleshooting Amazon EKS customer support cases.

#### Usage

At a high level, you run this script on your Kubernetes node, and it will collect system information, configuration and logs that will assist in troubleshooting issues with your node. AWS support and service team engineers can use this information once provided via a customer support case.

* Collect EKS logs using SSM agent, jump to below [section](#collect-eks-logs-using-ssm-agent) _(or)_

* Run this project as the root user

```
curl -O https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/eks-log-collector.sh
sudo bash eks-log-collector.sh
```

Confirm if the tarball file was successfully created (it can be .tgz or .tar.gz)

#### Retrieving the logs

Download the tarball using your favorite Secure Copy tool.

#### Example output

The project can be used in normal or enable_debug (**Caution: enable_debug will prompt to confirm if we can restart Docker daemon which would kill running containers**).

```
$ sudo bash eks-log-collector.sh --help

USAGE: eks-log-collector --help [ --ignore_introspection=true|false --ignore_metrics=true|false ]

OPTIONS:

   --ignore_introspection To ignore introspection of IPAMD; Pass this flag if DISABLE_INTROSPECTION is enabled on CNI

   --ignore_metrics Variable To ignore prometheus metrics collection; Pass this flag if DISABLE_METRICS enabled on CNI

   --help  Show this help message.
```

#### Example output in normal mode

The following output shows this project running in normal mode.

```
$ sudo bash eks-log-collector.sh

        This is version 0.7.3. New versions can be found at https://github.com/awslabs/amazon-eks-ami/blob/master/log-collector-script/

Trying to collect common operating system logs...
Trying to collect kernel logs...
Trying to collect mount points and volume information...
Trying to collect SELinux status...
Trying to collect iptables information...
Trying to collect installed packages...
Trying to collect active system services...
Trying to Collect Containerd daemon information...
Trying to Collect Containerd running information...
Trying to Collect Docker daemon information...

        Warning: The Docker daemon is not running.

Trying to collect kubelet information...
Trying to collect L-IPAMD introspection information... Trying to collect L-IPAMD prometheus metrics... Trying to collect L-IPAMD checkpoint...
Trying to collect Multus logs if they exist...
Trying to collect sysctls information...
Trying to collect networking infomation... conntrack v1.4.4 (conntrack-tools): 165 flow entries have been shown.

Trying to collect CNI configuration information...
Trying to collect Docker daemon logs...
Trying to Collect sandbox-image daemon information...
Trying to Collect CPU Throttled Process Information...
Trying to Collect IO Throttled Process Information...
Trying to archive gathered information...

        Done... your bundled logs are located in /var/log/eks_i-XXXXXXXXXXXXXXXXX_2022-12-19_1639-UTC_0.7.3.tar.gz
```

### Collect EKS logs using SSM agent

#### To run EKS log collector script on Worker Node(s) and upload the bundle(tar) to a S3 Bucket using SSM agent, please follow below steps

##### Prerequisites

* Configure AWS CLI on the system where you will run the below commands. The IAM entity (User/Role) should have permissions to run/invoke `aws ssm create-document`, `aws ssm send-command` and `aws ssm get-command-invocation` commands.

  * `ssm:CreateDocument`
  * `ssm:GetCommandInvocation`
  * `ssm:SendCommand`

* SSM agent should be installed and running on Worker Node(s). [How to Install SSM Agent link](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-manual-agent-install.html)

* Worker Node(s) should have required permissions to communicate with SSM service. IAM managed role `AmazonSSMManagedInstanceCore` will have all the required permission for SSM agent to run on EC2 instances. The IAM managed role `AmazonSSMManagedInstanceCore` has `S3:PutObject` permission to all S3 resources.

*Note:* For more granular control of the IAM permission check [Actions defined by AWS Systems Manager](https://docs.aws.amazon.com/IAM/latest/UserGuide/list_awssystemsmanager.html%23awssystemsmanager-actions-as-permissions)

* A S3 bucket location is required which is taken as an input parameter to `aws ssm send-command` command, to which the logs should be pushed.

#### To invoke SSM agent to run EKS log collector script and push bundle to S3 from Worker Node(s)

1. Create the SSM document named "EKSLogCollector" using the following commands:

```
curl -O https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/eks-ssm-content.json
aws ssm create-document \
  --name "EKSLogCollectorLinux" \
  --document-type "Command" \
  --content file://eks-ssm-content.json
```

2. To execute the bash script in the SSM document and to collect the logs from worker, run the following command:

```
aws ssm send-command \
  --instance-ids <EC2 Instance ID> \
  --document-name "EKSLogCollectorLinux" \
  --parameters "bucketName=<S3 bucket name to push the logs>" \
  --output json
```

3. To check the status of SSM command submitted in previous step use the command

```
aws ssm get-command-invocation \
  --command-id "<SSM command ID>" \
  --instance-id "<EC2 Instance ID>" \
  --output text
```

4. Once the above command is executed successfully, the logs should be present in the S3 bucket specified in the previous step.
