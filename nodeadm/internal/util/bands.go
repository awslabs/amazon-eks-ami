package util

func GetAmountFromPercentageBands(percentsPerRange []int, bounds []int, total uint64) (amount uint64) {
	for i, percentageToReserveForRange := range percentsPerRange {
		lowerBound := uint64(bounds[i])
		if total < lowerBound {
			break
		}
		topBound := uint64(bounds[i+1])
		if total < topBound {
			topBound = total
		}
		segmentSize := topBound - lowerBound
		amountFromSegment := ExtractPercentagePointsFromPortion(segmentSize, percentageToReserveForRange)
		amount = amount + amountFromSegment
	}

	return amount
}

func ExtractPercentagePointsFromPortion(portionSize uint64, percentagePoints int) uint64 {
	return uint64(float64(portionSize) * (float64(percentagePoints) / 100))
}
