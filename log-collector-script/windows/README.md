### EKS Logs Collector (Windows)

This project was created to collect Amazon EKS log files and OS logs for troubleshooting Amazon EKS customer support cases.

#### Usage

* Collect EKS logs using SSM agent, jump to below [section](#collect-eks-logs-using-ssm-agent) _(or)_

* Run this project as the Administrator user:

```
Invoke-WebRequest -OutFile eks-log-collector.ps1 https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/windows/eks-log-collector.ps1
.\eks-log-collector.ps1
```

#### Example output

The project can be used in normal or Enable/Disable Debug(**Caution: Enable/Disable Debug will restart Docker daemon which would kill running containers**).

```
USAGE: .\eks-log-collector.ps1
```

#### Example output in normal mode

The following output shows this project running in normal mode.

```
.\eks-log-collector.ps1
Running Default(Collect) Mode
Cleaning up directory
OK
Creating temporary directory
OK
Collecting System information
OK
Checking free disk space
C: drive has 58% free space
OK
Collecting System Logs
OK
Collecting Application Logs
OK
Collecting Volume info
OK
Collecting Windows Firewall info
Collecting Rules for Domain profile
Collecting Rules for Private profile
Collecting Rules for Public profile
OK
Collecting installed applications list
OK
Collecting Services list
OK
Collecting Docker daemon information
OK
Collecting Kubelet logs
OK
Collecting Kube-proxy logs
OK
Collecting kubelet information
OK
Collecting Docker daemon logs
OK
Collecting EKS logs
OK
Collecting network Information
OK
Archiving gathered data
Done... your bundled logs are located in  C:\log-collector\eks_i-0b318f704c74b6ab2_20200101T0620179658Z.zip
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
aws ssm create-document \
  --name "EKSLogCollectorWindows" \
  --document-type "Command" \
  --content https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/windows/eks-ssm-content.json
```

2. To execute the bash script in the SSM document and to collect the logs from worker, run the following command:

```
aws ssm send-command \
  --instance-ids <EC2 Instance ID> \
  --document-name "EKSLogCollectorWindows" \
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
