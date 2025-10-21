[Resolve]
{{ if .Nameservers }}DNS={{range $i, $v := .Nameservers}}{{ if $i }} {{ end }}{{$v}}{{ end }}{{ end }}
{{ if .Domains }}Domains={{range $i, $v := .Domains}}{{ if $i }} {{ end }}{{$v}}{{ end }}{{ end }}
