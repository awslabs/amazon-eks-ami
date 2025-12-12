[Resolve]
{{ if .Nameservers }}DNS={{join .Nameservers " "}}{{ end }}
{{ if .Domains }}Domains={{join .Domains " "}}{{ end }}
