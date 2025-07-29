package util

import (
	"math"
)

// GetAmountFromPercentageBands returns a summed total of amounts from the specified bands according to the
// provided ratios. Accuracy is only guaranteed per IEEE 754 double-preicision floating point conventions,
// which is generally sufficient for resources like CPU or total RAM that generally align to an accuracy bound.
func GetAmountFromPercentageBands(numeratorPerRange []int, bounds []int, total uint64, denominator int) uint64 {
	var runningTotal float64
	for i, numeratorForRange := range numeratorPerRange {
		lowerBound := uint64(bounds[i])
		if total < lowerBound {
			break
		}
		topBound := min(total, uint64(bounds[i+1]))
		segmentSize := topBound - lowerBound
		runningTotal += ExtractRatioFromPortion(segmentSize, numeratorForRange, denominator)
	}

	return uint64(math.Floor(runningTotal))
}

// ExtractRatioFromPortion returns the ratio defiend by numerator over denominator from the given
// portionSize. Callers should ensure numerator > denominator to avoid an integer overflow, and accuracy is
// only guaranteed per IEEE 754 standards (which implies full accuracy for all integers expressable in 53 bits, e.g.
// the equivalent of a bit over a petabyte)
func ExtractRatioFromPortion(portionSize uint64, numerator int, denominator int) float64 {
	return float64(portionSize) * (float64(numerator) / float64(denominator))
}
