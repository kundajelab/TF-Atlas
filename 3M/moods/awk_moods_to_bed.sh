#!/bin/bash
awk -F "," 'BEGIN { OFS="\t" }{print $1,$3,$3+length($6),$4,$2,$5,$6}' $1 > $2.bed
