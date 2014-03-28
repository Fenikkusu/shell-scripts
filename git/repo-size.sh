#!/bin/bash

# Script used to List Large Files of git repo. Will automatically remove all files ignored by .gitignore from the repo history.
# Work In Progress
# @author Phoenix Osiris
# @license mit

function renderHelp() {
	echo "Repo Size Claim Script"
	echo " "
	echo "Options:"
	echo "-h         Show this screen"
	echo "-c         Disable Auto Clean"
	echo "-d [path]  Specify the Directory to Run On (Must be the root containing the .git folder). Defaults to $(pwd)."
	echo "-q         Enable Quiet Mode. Only Outputs File Names"
	echo "-s [n]     Only include files of at least n MB in size"
	echo "-i         Disable Automatic Removal of Ignored Files"
	echo "-f [path]  Specifies the path file for a prebuilt list of big files"
	echo "-o [path]  Specifies a path to save the files list too. Can then be loaded using -f"
	echo "-b         Disables Backup"
}

function showMessage() {
	if [ !$bQuiet ]; then
		if [ $2 ]; then
			echo -ne "$1\r"
		else
			let iCols=$(tput cols)
			let iLength=${#1}
			let iCols-=$iLength
			sBlank=$(head -c $iCols < /dev/zero | tr '\0' ' ')
			echo -e "$1$sBlank"
		fi
	fi
}

#Set Defaults
sPath=$(pwd);
bClean=true;
bQuiet=false;
iMaxSize=0;
bIgnored=true;
vIFS=$IFS;
sIndexFile="./../tmp.Index.log"
sFilesFile="./../tmp.Files.log"

let iMaxArgs=$(getconf ARG_MAX)-100

#Build Options
while getopts hcd:qsi:o: option
do
	case "${option}"
	in
		h) 
			renderHelp
			exit 0;;
		c) bClean=false;;
		d) sPath=${OPTARG};;
		q) bQuiet=true;;
		s) let iMaxSize=${OPTARG} / 1024;;
		i) bIgnored=false;;
	esac
done

#Check that provided directory exists
if ! [ -d $sPath ]; then
	echo "ERROR: Path Not Found Or Is Not A Directory: $sPath"
	echo " "
	renderHelp
	exit 1;
fi

showMessage "Entering $sPath"

pushd "${sPath}" > /dev/null
	if ! [ -d .git ]; then
		echo "ERROR: Directory is not a Git Repository"
		echo " "
		renderHelp
		exit 2;
	fi
	
	showMessage "Building File Hash List..." true
		git rev-list --objects --all | sort -k 2 > $sIndexFile
	showMessage "Building File Hash List...Done!"

	if [ $bClean == true ]; then
		showMessage "Cleaning Repo..." true
		git gc > /dev/null 2>&1
		showMessage "Cleaning Repo...Done!"
		fi

		showMessage "Building Sizes..." true
		sObjects=$(git verify-pack -v .git/objects/pack/pack-*.idx | egrep "^\w+ blob\W+[0-9]+ [0-9]+ [0-9]+$" | sort -k 3 -n -r)
	showMessage "Building Sizes...Done!"
	
	IFS=$'\n'
	iTotal=0
	for sObject in $sObjects; do
		let iTotal+=1
		showMessage "Counting Objects...$iTotal" true
	done
	showMessage "Counting Objects...Done!"
	
	iCount=0
	let iCols=$(tput cols)-22;
	
	if [ -f $sFilesFile ]; then 
		rm $sFilesFile;
	fi
	
	for sObject in $sObjects; do
		SHA=$(echo "$sObject" | cut -f 1 -d\ )
		
		sIndex=$(grep $SHA $sIndexFile);
		if [ -z "$sIndex" ]; then
			continue
		fi
		
		iSize=$(echo "$sObject" | awk '{print $3}');
		sFile=$(echo "$sIndex" | awk '{print $2}');

		if [ $iMaxSize == 0 -o $iSize -gt $iMaxSize ]; then
			echo $'\n'"$sFile" >> $sFilesFile
		fi
	
		let iCount+=1
		let iRemaining=$iTotal-$iCount
		showMessage "Processing...$iRemaining Items Remaining..." true
	done;

	showMessage "Processing...Done! $sBlank"
	
	if [ $sIndexFile != "./../tmp.Index.log" ]; then
		rm $sIndexFile
	fi
	
	
	if [ $bIgnored ]; then
		DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
		pushd $DIR
			./ignored-files.sh -d $sPath -f $sFilesFile -i
		popd
	else
		cat $sFilesFile;
	fi
	
	if [ $sFilesFile != "./../tmp.Files.log" ]; then
		rm $sFilesFile
	fi
	
	showMessage "Leaving $sPath"
popd > /dev/null

exit 0;

#sFiles=$(git rev-list --objects --all | sort -k 2)
#sObjects=$(git gc && git verify-pack -v .git/objects/pack/pack-*.idx | egrep "^\w+ blob\W+[0-9]+ [0-9]+ [0-9]+$" | sort -k 3 -n -r)
#for SHA in `echo "$sObjects" | cut -f 1 -d\ `; do
#	sHash=$(echo "$sObjects" | grep $SHA);
#	sFile=$(echo "$sFiles" | grep $SHA);
#	
#	iSize=$(echo "$sHash" | awk '{print $3}');
#	sHash=$(echo "$sHash" | awk '{print $1}');
#	sFile=$(echo "$sFile" | awk '{print $2}');
#	
#	echo "$sHash $iSize $sFile";
#done;