package util

import (
	"bytes"
	"fmt"
	"io"
	"strings"
)

type MarkdownWriter interface {
	WriteHeader(record []string) error
	Write(record []string) error
}

type markdownWriter struct {
	w io.Writer
}

func NewMarkdownWriter(w io.Writer) MarkdownWriter {
	return &markdownWriter{
		w: w,
	}
}

func (m *markdownWriter) Write(record []string) error {
	var buf bytes.Buffer
	fmt.Fprint(&buf, "| ")
	fmt.Fprint(&buf, strings.Join(record, " | "))
	fmt.Fprintln(&buf, " |")
	_, err := io.Copy(m.w, &buf)
	return err
}

func (m *markdownWriter) WriteHeader(record []string) error {
	if err := m.Write(record); err != nil {
		return err
	}
	separator := make([]string, len(record))
	for i := range separator {
		separator[i] = "---"
	}
	return m.Write(separator)
}
