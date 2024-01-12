package util

import "strings"

var (
	spaceCharacters = map[byte]struct{}{
		' ':  {},
		'\t': {},
	}
	newlineCharacters = map[byte]struct{}{
		'\n': {},
		'\r': {},
	}
)

// Dedent removes leading space characters from each line in a string.
func Dedent(s string) string {
	var res strings.Builder
	leadingSpaces := true
	for i := 0; i < len(s); i++ {
		if _, ok := spaceCharacters[s[i]]; leadingSpaces && ok {
			continue
		} else if _, ok := newlineCharacters[s[i]]; ok {
			leadingSpaces = true
		} else {
			leadingSpaces = false
		}
		res.WriteByte(s[i])
	}
	return res.String()
}
