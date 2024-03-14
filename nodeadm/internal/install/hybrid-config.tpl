[profile hybrid]
    credential_process = aws_signing_helper credential-process --certificate /etc/iam/pki/server.pem --private-key /etc/iam/pki/server.key --trust-anchor-arn {{ .AnchorARN }} --profile-arn {{ .ProfileARN }} --role-arn {{ .RoleARN }}
