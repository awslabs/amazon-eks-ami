package util

import (
	"math"
)

func GetAmountFromPercentageBands(percentsPerRange []int, bounds []int, total int) (amount int) {
	for i, percentageToReserveForRange := range percentsPerRange {
		lowerbound := bounds[i]
		if total < lowerbound {
			break
		}
		topBound := int(math.Min(float64(total), float64(bounds[i+1])))
		amount = amount + int((float64(topBound)-float64(lowerbound))*(float64(percentageToReserveForRange)/100))
	}

	return amount
}
