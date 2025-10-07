package flaggy

import (
	"strings"
)

// EnableCompletion enables shell autocomplete outputs to be generated.
func EnableCompletion() {
	DefaultParser.ShowCompletion = true
}

// EnableCompletion disallows shell autocomplete outputs to be generated.
func DisableCompletion() {
	DefaultParser.ShowCompletion = false
}

// GenerateBashCompletion returns a bash completion script for the parser.
func GenerateBashCompletion(p *Parser) string {
	var b strings.Builder
	funcName := "_" + sanitizeName(p.Name) + "_complete"
	b.WriteString("# bash completion for " + p.Name + "\n")
	b.WriteString(funcName + "() {\n")
	b.WriteString("    local cur prev\n")
	b.WriteString("    COMPREPLY=()\n")
	b.WriteString("    cur=\"${COMP_WORDS[COMP_CWORD]}\"\n")
	b.WriteString("    prev=\"${COMP_WORDS[COMP_CWORD-1]}\"\n")
	b.WriteString("    case \"$prev\" in\n")
	bashCaseEntries(&p.Subcommand, &b)
	rootOpts := collectOptions(&p.Subcommand)
	b.WriteString("        *)\n            COMPREPLY=( $(compgen -W \"" + rootOpts + "\" -- \"$cur\") )\n            return 0\n            ;;\n    esac\n}\n")
	b.WriteString("complete -F " + funcName + " " + p.Name + "\n")
	return b.String()
}

// GenerateZshCompletion returns a zsh completion script for the parser.
func GenerateZshCompletion(p *Parser) string {
	var b strings.Builder
	funcName := "_" + sanitizeName(p.Name)
	b.WriteString("#compdef " + p.Name + "\n\n")
	b.WriteString(funcName + "() {\n")
	b.WriteString("    local cur prev\n")
	b.WriteString("    cur=${words[CURRENT]}\n")
	b.WriteString("    prev=${words[CURRENT-1]}\n")
	b.WriteString("    case \"$prev\" in\n")
	zshCaseEntries(&p.Subcommand, &b)
	rootOpts := collectOptions(&p.Subcommand)
	b.WriteString("        *)\n            compadd -- " + rootOpts + "\n            ;;\n    esac\n}\n")
	b.WriteString("compdef " + funcName + " " + p.Name + "\n")
	return b.String()
}

// collectOptions builds a space-delimited list of flags, subcommands, and positional values
// for the provided subcommand.
func collectOptions(sc *Subcommand) string {
	var opts []string
	for _, f := range sc.Flags {
		if len(f.ShortName) > 0 {
			opts = append(opts, "-"+f.ShortName)
		}
		if len(f.LongName) > 0 {
			opts = append(opts, "--"+f.LongName)
		}
	}
	for _, p := range sc.PositionalFlags {
		if p.Name != "" {
			opts = append(opts, p.Name)
		}
	}
	for _, s := range sc.Subcommands {
		if s.Hidden {
			continue
		}
		if s.Name != "" {
			opts = append(opts, s.Name)
		}
		if s.ShortName != "" {
			opts = append(opts, s.ShortName)
		}
	}
	return strings.Join(opts, " ")
}

func bashCaseEntries(sc *Subcommand, b *strings.Builder) {
	for _, s := range sc.Subcommands {
		if s.Hidden {
			continue
		}
		opts := collectOptions(s)
		b.WriteString("        " + s.Name + ")\n            COMPREPLY=( $(compgen -W \"" + opts + "\" -- \"$cur\") )\n            return 0\n            ;;\n")
		if s.ShortName != "" {
			b.WriteString("        " + s.ShortName + ")\n            COMPREPLY=( $(compgen -W \"" + opts + "\" -- \"$cur\") )\n            return 0\n            ;;\n")
		}
		bashCaseEntries(s, b)
	}
}

func zshCaseEntries(sc *Subcommand, b *strings.Builder) {
	for _, s := range sc.Subcommands {
		if s.Hidden {
			continue
		}
		opts := collectOptions(s)
		b.WriteString("        " + s.Name + ")\n            compadd -- " + opts + "\n            return\n            ;;\n")
		if s.ShortName != "" {
			b.WriteString("        " + s.ShortName + ")\n            compadd -- " + opts + "\n            return\n            ;;\n")
		}
		zshCaseEntries(s, b)
	}
}

func sanitizeName(n string) string {
	return strings.ReplaceAll(n, "-", "_")
}
