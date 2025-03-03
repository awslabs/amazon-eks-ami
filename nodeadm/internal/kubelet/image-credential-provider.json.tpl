{
  "apiVersion": "{{.ConfigApiVersion}}",
  "kind": "CredentialProviderConfig",
  "providers": [
    {
      "name": "{{.EcrProviderName}}",
      "matchImages": [
        {{- range $index, $matchImage := .MatchImages}}
        {{- if $index}},{{end}}
        "{{$matchImage}}"
        {{- end}}
      ],
      "defaultCacheDuration": "12h",
      "apiVersion": "{{.ProviderApiVersion}}"
    }
  ]
}