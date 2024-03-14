apiVersion: v1
kind: Config
clusters:
  - name: kubernetes
    cluster:
      certificate-authority: {{.CaCertPath}}
      server: {{.APIServerEndpoint}}
current-context: kubelet
contexts:
  - name: kubelet
    context:
      cluster: kubernetes
      user: kubelet
users:
- name: kubelet
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      env:
        - name: AWS_CONFIG_FILE
          value: /etc/eks/hybrid-config
        - name: AWS_PROFILE
          value: hybrid
      args:
        - 'token'
        - -i
        - '{{ .Cluster }}'
        - --region
        - '{{ .Region }}'
        - --session-name
        - '{{ .SessionName }}'
        - --role
        - '{{ .RoleARN }}'
