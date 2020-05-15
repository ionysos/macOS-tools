#!/bin/bash
set -e



# Variables
win10ISO=$(mdfind 'win 10 .iso' | head -n 1)
usbDrive=$(diskutil list | sed -n 's|^/dev/\(disk[0-9]*\).*|\1|p' | tail -n 1)
usbDriveName=$(df | sed -n "s|^/dev/$usbDrives[0-9]*\(.*\).*|\1|p" | tail -n 1 | sed -n 's|.*/\(.*\)$|\1|p')

# Statics
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'
quesMsg="${yel}%s [if not '%s']:${end} "
quesEMsg="${yel}%s [if not '%s' (%s)]:${end} "
erroMsg="${red}✘\t%s [expected: '%s']${end}\n"
erroEMsg="${red}✘\t%s [expected: '%s' (%s)]${end}\n"
warnMsg="\n${mag}!\t%s${end}\n\n"
taskMsg="${yel}%s:${end}\t"
rsltMsg="${grn}✔${end}\n"
nwLnMsg='\n\n---\n\n\n'

# Functions
while getopts 'av' 2> /dev/null flag
do
	case "${flag}" in
		a) printf '%s\n' 'Author: ionysos (https://ionysos.github.io/)'
		   exit 0;;
		v) printf '%s\n%s\n%s\n' 'Version: v0.6 (2020-05-15)' \
		   "$(basename -- $0) (https://github.com/ionysos/macOS-tools/blob/master/bootable-usb-win10.sh)" \
		   'License: MIT (https://github.com/ionysos/macOS-tools/blob/master/LICENSE)'
		   exit 0;;
		*) printf "$erroMsg" 'Flag not supported' "a', 'v"
		   exit 1;;
	esac
done
function get_input {
	if ! [[ -z "$3" ]]
	then
		local msg=$(printf "$quesEMsg" "$1" "$2" "$3")
	else
		local msg=$(printf "$quesMsg" "$1" "$2")
	fi
	read -p "$msg"
	REPLY=$(printf "$REPLY" | tail -n 1 | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
	if ! [[ -z "$REPLY" ]]
	then
		printf "$REPLY"
	else
		printf "$2"
	fi
}


## Check OS
if [[ "$OSTYPE" != 'darwin'* ]]
then
	printf "$erroEMsg" 'OS not supported' 'macOS' 'darwin'
	exit 1
fi

## Prepare system
if ! [[ -x "$(command -v wimlib-imagex)" ]]
then
	printf "$erroEMsg" 'Dependency not available' 'wimlib' 'wimlib-imagex'
	printf '\n\t%s\n' 'E.g.: install it via Homebrew (https://brew.sh/)'
	printf '\t\t%s\n' 'brew install wimlib'
	exit 1
fi

## Print download URL
printf '%s\n\n' 'Download Win10 ISO file from: https://www.microsoft.com/software-download/windows10'

## Ask for file path
win10ISO=$(get_input 'Win10 ISO file path' "$win10ISO")

## Ask for disk name
usbDrive=$(get_input 'USB drive disk name' "$usbDrive" "$usbDriveName")

## Print formatting warning
printf "$warnMsg" 'Disk formatting leads to irrecoverable data erasure'

## Ask for disk formatting
eraseDisk='no'
eraseDisk=$(get_input "Format disk '$usbDrive'? ('yes')" "$eraseDisk")

## Format disk
if [[ "$eraseDisk" == 'yes' ]]
then
	if [[ -e "/dev/$usbDrive" ]]
	then
		usbName='WIN10'
		printf "\n$taskMsg\t\t\t\t\t\t" "Format disk '$usbDrive'"
		diskutil eraseDisk MS-DOS "$usbName" MBR "$usbDrive" > /dev/null
		sleep 3
		printf "$rsltMsg"
	else
		printf "$erroMsg" 'Disk not available' "$usbDrive"
		exit 1
	fi
else
	printf "$erroMsg" 'User abortion' 'NONE'
	exit 1
fi

## Mount ISO
if [[ -f "$win10ISO" ]]
then
	printf "$taskMsg\t" "Mount ISO '$win10ISO'"
	volume=$(hdiutil mount "$win10ISO" | cut -f3)
	sleep 3
	printf "$rsltMsg"
else
	printf "$erroMsg" 'ISO not available' "$win10ISO"
	exit 1
fi

## Print long-lasting copy warning
printf "$warnMsg" 'File copy lasts several minutes (~10min)'

## Copy files
usbVolume="/Volumes/$usbName"
if [[ -d "$volume" ]] && [[ -d "$usbVolume" ]]
then
	specFile='sources/install.'
	specFileEnd='wim'
	specFileSEnd='swm'
	printf "$taskMsg" "Copy files ('$volume' -> '$usbVolume')"
	printf '...'
	rsync -qa --exclude="$specFile$specFileEnd" "$volume/" "$usbVolume"
	printf '1/2...'
	if [[ -f "$volume/$specFile$specFileEnd" ]]
	then
		wimlib-imagex split "$volume/$specFile$specFileEnd" "$usbVolume/$specFile$specFileSEnd" 4000 > /dev/null
	else
		printf "$erroMsg" 'Win10 file missing' "$volume/$specFile$specFileEnd"
		exit 1
	fi
	printf '2/2...'
	sleep 3
	printf " $rsltMsg"
else
	printf "$erroMsg" 'Volume(s) not available' "$volume', '$usbVolume"
	exit 1
fi

## Eject disk
if [[ -d "$usbVolume" ]]
then
        printf "$taskMsg\t\t\t\t\t" "Eject disk '$usbVolume'"
        hdiutil eject "$usbVolume" > /dev/null
        printf "$rsltMsg"
else
        printf "$erroMsg" 'Disk not available' "$usbVolume"
        exit 1
fi

## Eject volume
if [[ -d "$volume" ]]
then
	printf "$taskMsg\t\t" "Eject volume '$volume'"
	hdiutil eject "$volume" > /dev/null
	printf "$rsltMsg"
else
	printf "$erroMsg" 'Volume not available' "$volume"
	exit 1
fi

