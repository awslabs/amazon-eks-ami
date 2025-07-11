package util

import (
	"fmt"

	"golang.org/x/text/language"
	"golang.org/x/text/message"
)

// Cast float64 to string with two decimal points
func Float64ToStr(num float64) string {
	return fmt.Sprintf("%.2f", num)
}

// Cast int to string and commas to split up larger numbers
func NumToStr(num int) string {
	p := message.NewPrinter(language.English)
	return p.Sprintf("%d", num)
}
