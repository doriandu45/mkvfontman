#!/bin/bash
source "lib.sh"

# Arguments parsing

case "$1" in
	"list") # Lists all fonts
	case "${2: -3}" in
		"mkv" | "mks" | "mka")
			parseMkv "$2"
			printf "\e[32mUsed fonts: %s\n" "${usedFonts[@]}"
			printf "\e[31mMissing fonts: %s\n" "${missingFonts[@]}"
			printf "\e[1;33mUseless fonts: %s\e[0m\n" "${uselessFonts[@]}"
		;;
		"ass" | "ssa")
			#TODO
			echo "This will be added soon(TM)"
		;;
		*)
			echo "ERROR: Unknown extension for $2">&2
			echo "Only mkv/mka/mks and ass/ssa are supported in list mode">&2
			exit 1
		;;
	esac
	;;
	"autoclean")
		if ! [[ "${2: -3}" = "mkv" || "${2: -3}" = "mks" || "${2: -3}" = "mka" ]]
		then
			echo "ERROR: Unknown extension for $2">&2
			echo "Only mkv/mka/mks are supported in autoclean mode">&2
			exit 1
		fi
		parseMkv "$2"
		parseFontStore
		printf "\e[32mFonts to add: %s\n" "${fontsToAdd[@]}"
		printf "\e[1;33mUseless fonts (will be removed): %s\n" "${uselessFonts[@]}"
		printf "\e[1;31mMissing fonts (not in fontstore): %s\e[0m\n" "${missingFonts[@]}"
		cleanMatroska "$2"
		
	;;
	"help" | "-h" | "--help" | "?" | "-?")
		echo "More helpfull help message will come soon(TM)"
		echo "For now, you can use:"
		echo "$0 <list | autoclean> <file>"
		echo "list: only list the fonts from a file"
		echo "autoclean: automatically remove useless fonts and add missing font if they are present in the fontstore"
	;;
	*)
		echo "ERROR: Unknown function $1">&2
		echo "See $0 help for more details">&2
		exit 1
	;;
esac