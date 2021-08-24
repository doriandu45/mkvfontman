#!/bin/bash


# Prints all fonts used by an .ass or .ssa file passed as $1
function printFontsAss() {
	# Main styles
	grep '^Style: *' "$1" | awk -F',' '{print $2}'
	# Fonts embedded in lines with "\fn"
	sed -En 's/.*\\fn([^\\}]*)[\\}].*/\1/gp' "$1"
}

printFontsAss "$1"