# Changelog

1.5.1 - 08/04/2020
-----------------------
- docker version updated to `19.03.6ce-4.amzn2`
- Updated latest build date for 1.15.11  to `2020-07-17`
- Updated `kernel.pid_max = 999999`

1.5.0 - 05/12/2020
-----------------------
- Sync code with upstream

1.4.2 - 05/06/2020
-----------------------
- downgraded docker version to 18.09.9ce-2.amzn2
- cni plugin version downgraded v0.7.5  

1.4.1 - 05/04/2020
-----------------------
- Upgrade to EKS 1.15.11
- kernel version set to 4.14.133-113.112.amzn2

1.4.0 - 04/17/2020
-----------------------
- Upgrade to EKS 1.15

1.3.0 - 04/01/2020
-----------------------
- Adding AWS Inspector Agent

1.2.0 - 08/06/2019
-----------------------
- Adding `southwest-aws` as an option for an account to create the AMI in

1.1.0 - 06/20/2019
-----------------------
- Upgrade to EKS 1.13

1.0.1 - 06/18/2019
-----------------------
- Fix issue with pull request and merge builds. It should now automatically build an imgae in the AWS development account for pull requests and all the accounts for merges

1.0.0 - 06/18/2019
-----------------------
- Update Amazon Linux 2 AMI with OpenGov customization and Jenkins pipeline support - adds encryption and AWS SSM agent
