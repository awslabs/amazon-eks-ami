### <span style="font-family: times, serif; font-size:16pt; font-style:italic;"> EKS Logs Collector 

<span style="font-family: calibri, Garamond, 'Comic Sans MS' ;">This project was created to collect Amazon EKS log files and OS logs for troubleshooting Amazon EKS customer support cases.</span>

# Table of contents
1. [`eks-log-collector.sh` Usage (For node specific logs)](#eks-log-collectorsh-usage-for-node-specific-logs)
2. [`eks-log-collector.sh` Usage (For node specific logs) using SSM agent](#collect-eks-logs-using-ssm-agent)
3. [`kubectl-collector.sh` Usage (For Cluster level config)](#kubectl-collectorsh-usage-for-cluster-level-config)

--- 

### `eks-log-collector.sh` Usage (For node specific logs)

At a high level, you run this script on your Kubernetes node, and it will collect system information, configuration and logs that will assist in troubleshooting issues with your node. AWS support and service team engineers can use this information once provided via a customer support case.

* Collect EKS logs using SSM agent, jump to below [section](#collect-eks-logs-using-ssm-agent) _(or)_

* Run this project as the root user:
```
curl -O https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/eks-log-collector.sh
sudo bash eks-log-collector.sh
```

Confirm if the tarball file was successfully created (it can be .tgz or .tar.gz)

#### Retrieving the logs
Download the tarball using your favourite Secure Copy tool.

#### Example output
The project can be used in normal or enable_debug(**Caution: enable_debug will prompt to confirm if we can restart Docker daemon which would kill running containers**).

```
# sudo bash eks-log-collector.sh --help
USAGE: eks-log-collector --help [ --ignore_introspection=true|false --ignore_metrics=true|false ]

OPTIONS:
   --ignore_introspection   To ignore introspection of IPAMD; Pass this flag if DISABLE_INTROSPECTION is enabled on CNI
   
   --ignore_metrics         To ignore prometheus metrics collection; Pass this flag if DISABLE_METRICS enabled on CNI

   --help  Show this help message.

Example to Ignore IPAMD introspection: 
sudo bash eks-log-collector.sh --ignore_introspection=true

Example to Ignore IPAMD Prometheus metrics collection:  
sudo bash eks-log-collector.sh --ignore_metrics=true

Example to Ignore IPAMD introspection and Prometheus metrics collection:
sudo bash eks-log-collector.sh --ignore_introspection=true --ignore_metrics=true   
```
#### Example output in normal mode
The following output shows this project running in normal mode.

```
sudo bash eks-log-collector.sh

	This is version 0.6.1. New versions can be found at https://github.com/awslabs/amazon-eks-ami

Trying to collect common operating system logs... 
Trying to collect kernel logs... 
Trying to collect mount points and volume information... 
Trying to collect SELinux status... 
Trying to collect iptables information... 
Trying to collect installed packages... 
Trying to collect active system services... 
Trying to collect Docker daemon information... 
Trying to collect kubelet information... 
Trying to collect L-IPAMD information... 
Trying to collect sysctls information... 
Trying to collect networking infomation... 
Trying to collect CNI configuration information... 
Trying to collect running Docker containers and gather container data... 
Trying to collect Docker daemon logs... 
Trying to archive gathered information... 

	Done... your bundled logs are located in /var/log/eks_i-0717c9d54b6cfaa19_2020-03-24_0103-UTC_0.6.1.tar.gz
```


### Collect EKS logs using SSM agent 
#### <span style="font-family: times, serif; font-size:16pt; font-style:italic;">To run EKS log collector script on Worker Node(s) and upload the bundle(tar) to a S3 Bucket using SSM agent, please follow below steps

##### *Prerequisites*:

* Configure AWS CLI on the system where you will run the below commands. The IAM entity (User/Role) should have permissions to run/invoke `aws ssm send-command` and `get-command-invocation` commands.

* SSM agent should be installed and running on Worker Node(s). [How to Install SSM Agent link](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-manual-agent-install.html)

* Worker Node(s) should have required permissions to communicate with SSM service. IAM managed role `AmazonEC2RoleforSSM` will have all the required permission for SSM agent to run on EC2 instances. The IAM managed role `AmazonEC2RoleforSSM` has `S3:PutObject` permission to all S3 resources. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*Note:* For more granular control of the IAM permission check [AWS Systems Manager Permissions link ](https://docs.aws.amazon.com/systems-manager/latest/userguide/auth-and-access-control-permissions-reference.html)

* A S3 bucket location is required which is taken as an input parameter to `aws ssm send-command` command, to which the logs should be pushed.


#### *To invoke SSM agent to run EKS log collector script and push bundle to S3 from Worker Node(s):*

1. Create the SSM document named "EKSLogCollector" using the following command: <br/>
```
aws ssm create-document --name "EKSLogCollector" --document-type "Command" --content https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/eks-ssm-content.json
```
2. To execute the bash script in the SSM document and to collect the logs from worker, run the following command: <br/>
```
aws ssm send-command --instance-ids <EC2 Instance ID> --document-name "EKSLogCollector" --parameters "bucketName=<S3 bucket name to push the logs>" --output json
```
3. To check the status of SSM command submitted in previous step use the command <br/> 
```   
aws ssm get-command-invocation --command-id "<SSM command ID>" --instance-id "<EC2 Instance ID>" --output text
```
&nbsp;&nbsp;&nbsp;&nbsp;`SSM command ID`One of the response parameters after running `aws ssm send-command` in step2<br/>
&nbsp;&nbsp;&nbsp;&nbsp;`EC2 Instance ID`The EC2 Instance ID provided in the `aws ssm send-command` in step2

4. Once the above command is executed successfully, the logs should be present in the S3 bucket specified in the previous step. 

### `kubectl-collector.sh` Usage (For Cluster level config)
At a high level, you run this script on machine with kubectl installed, and script will collect basic (get, describe) information from Kubernetes API Server that will assist in providing visibility of Kuberbetes Cluster objects. AWS support and service team engineers can use this information once provided via a customer support case.

```
curl -O https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/kubectl-collector.sh
sudo bash kubectl-collector.sh
```

Post execution, confirm if that tarball file (it can be .tgz or .tar.gz) was successfully created in the same directory as script execution.

#### Example output in normal mode

   ```
   $ bash kubectl-collector.sh
   Trying... kubectl get configmap aws-auth -n kube-system -o yaml
   Trying... kubectl get daemonset aws-node -n kube-system -o yaml
   Trying... kubectl get daemonset kube-proxy -n kube-system -o yaml
   Trying... kubectl get configmap kube-proxy -n kube-system -o yaml
   Trying... kubectl get configmap kube-proxy-config -n kube-system -o yaml
   Trying... kubectl get deployment coredns -n kube-system -o yaml
   Trying... kubectl get configmap coredns -n kube-system -o yaml
   Trying... kubectl get bindings --all-namespaces -o wide
   Error from server (NotFound): Unable to list "/v1, Resource=bindings": the server could not find the requested resource

   Trying... kubectl get componentstatuses --all-namespaces -o wide
   Warning: v1 ComponentStatus is deprecated in v1.19+

   Trying... kubectl get configmaps --all-namespaces -o wide

   Trying... kubectl get endpoints --all-namespaces -o wide

   Trying... kubectl get events --all-namespaces -o wide

   Trying... kubectl get limitranges --all-namespaces -o wide
   No resources found

   Trying... kubectl get nodes --all-namespaces -o wide

   Trying... kubectl get persistentvolumeclaims --all-namespaces -o wide

   Trying... kubectl get persistentvolumes --all-namespaces -o wide

   Trying... kubectl get pods --all-namespaces -o wide

   Trying... kubectl get podtemplates --all-namespaces -o wide
   No resources found

   Trying... kubectl get replicationcontrollers --all-namespaces -o wide
   No resources found

   Trying... kubectl get resourcequotas --all-namespaces -o wide
   No resources found

   Trying... kubectl get secrets --all-namespaces -o wide

   Trying... kubectl get serviceaccounts --all-namespaces -o wide

   Trying... kubectl get services --all-namespaces -o wide

   Trying... kubectl get challenges --all-namespaces -o wide
   No resources found

   Trying... kubectl get orders --all-namespaces -o wide
   No resources found

   Trying... kubectl get mutatingwebhookconfigurations --all-namespaces -o wide

   Trying... kubectl get validatingwebhookconfigurations --all-namespaces -o wide

   Trying... kubectl get customresourcedefinitions --all-namespaces -o wide

   Trying... kubectl get apiservices --all-namespaces -o wide

   Trying... kubectl get gatewayroutes --all-namespaces -o wide
   No resources found

   Trying... kubectl get meshes --all-namespaces -o wide

   Trying... kubectl get virtualgateways --all-namespaces -o wide
   No resources found

   Trying... kubectl get virtualnodes --all-namespaces -o wide

   Trying... kubectl get virtualrouters --all-namespaces -o wide

   Trying... kubectl get virtualservices --all-namespaces -o wide

   Trying... kubectl get controllerrevisions --all-namespaces -o wide

   Trying... kubectl get daemonsets --all-namespaces -o wide

   Trying... kubectl get deployments --all-namespaces -o wide

   Trying... kubectl get replicasets --all-namespaces -o wide

   Trying... kubectl get statefulsets --all-namespaces -o wide
   No resources found

   Trying... kubectl get tokenreviews --all-namespaces -o wide
   Error from server (MethodNotAllowed): the server does not allow this method on the requested resource

   Trying... kubectl get localsubjectaccessreviews --all-namespaces -o wide
   Error from server (NotFound): Unable to list "authorization.k8s.io/v1, Resource=localsubjectaccessreviews": the server could not find the requested resource

   Trying... kubectl get selfsubjectaccessreviews --all-namespaces -o wide
   Error from server (MethodNotAllowed): the server does not allow this method on the requested resource

   Trying... kubectl get selfsubjectrulesreviews --all-namespaces -o wide
   Error from server (MethodNotAllowed): the server does not allow this method on the requested resource

   Trying... kubectl get subjectaccessreviews --all-namespaces -o wide
   Error from server (MethodNotAllowed): the server does not allow this method on the requested resource

   Trying... kubectl get horizontalpodautoscalers --all-namespaces -o wide

   Trying... kubectl get cronjobs --all-namespaces -o wide
   No resources found

   Trying... kubectl get jobs --all-namespaces -o wide

   Trying... kubectl get certificaterequests --all-namespaces -o wide

   Trying... kubectl get certificates --all-namespaces -o wide

   Trying... kubectl get clusterissuers --all-namespaces -o wide
   No resources found

   Trying... kubectl get issuers --all-namespaces -o wide

   Trying... kubectl get certificatesigningrequests --all-namespaces -o wide
   No resources found

   Trying... kubectl get leases --all-namespaces -o wide

   Trying... kubectl get eniconfigs --all-namespaces -o wide
   No resources found

   Trying... kubectl get endpointslices --all-namespaces -o wide

   Trying... kubectl get ingressclassparams --all-namespaces -o wide

   Trying... kubectl get targetgroupbindings --all-namespaces -o wide
   No resources found

   Trying... kubectl get events --all-namespaces -o wide

   Trying... kubectl get ingresses --all-namespaces -o wide

   Trying... kubectl get flowschemas --all-namespaces -o wide

   Trying... kubectl get prioritylevelconfigurations --all-namespaces -o wide

   Trying... kubectl get alertmanagers --all-namespaces -o wide
   No resources found

   Trying... kubectl get prometheuses --all-namespaces -o wide

   Trying... kubectl get servicemonitors --all-namespaces -o wide

   Trying... kubectl get ingressclasses --all-namespaces -o wide

   Trying... kubectl get ingresses --all-namespaces -o wide

   Trying... kubectl get networkpolicies --all-namespaces -o wide
   No resources found

   Trying... kubectl get runtimeclasses --all-namespaces -o wide
   No resources found

   Trying... kubectl get poddisruptionbudgets --all-namespaces -o wide

   Trying... kubectl get podsecuritypolicies --all-namespaces -o wide
   Warning: policy/v1beta1 PodSecurityPolicy is deprecated in v1.21+, unavailable in v1.25+

   Trying... kubectl get clusterrolebindings --all-namespaces -o wide

   Trying... kubectl get clusterroles --all-namespaces -o wide

   Trying... kubectl get rolebindings --all-namespaces -o wide

   Trying... kubectl get roles --all-namespaces -o wide

   Trying... kubectl get priorityclasses --all-namespaces -o wide

   Trying... kubectl get csidrivers --all-namespaces -o wide

   Trying... kubectl get csinodes --all-namespaces -o wide

   Trying... kubectl get csistoragecapacities --all-namespaces -o wide
   No resources found

   Trying... kubectl get storageclasses --all-namespaces -o wide

   Trying... kubectl get volumeattachments --all-namespaces -o wide
   No resources found

   Trying... kubectl get securitygrouppolicies --all-namespaces -o wide
   No resources found

   Trying... archive gathered information

      Done... your kubectl command logs are located in

      $(pwd)/eks_kubectl_commands_2022-04-09_1238-EDT.tar.gz
   ```