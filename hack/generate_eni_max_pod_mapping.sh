#!/bin/bash

inputFile=$1
outputFile=$2

echo "package util" > $outputFile
echo "" >> $outputFile
echo "// Instance_types_map generated from eni-max-pods.txt DO NOT EDIT" >> $outputFile
echo "var Instance_types_map = map[string]int{" >> $outputFile

# - Skip lines starting with '#'
# - Format remaining lines into Go map entries
grep -v '^#' $inputFile | grep -v '^$' | awk '{print "\t\""$1"\":\t\t"$2","}' >> $outputFile

echo "}" >> $outputFile
