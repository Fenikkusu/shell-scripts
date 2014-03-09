#!/bin/bash

# Script used to List files ignored by .gitignore file. Can automatically remove all files ignored by .gitignore from the repo history.
# Work In Progress
# @author Phoenix Osiris
# @license mit

function renderHelp() {
	echo "Repo Ignored Files Script"
	echo " "
	echo "Options:"
	echo "-h         Show this screen"
	echo "-c         Disable Auto Clean"
	echo "-d [path]  Specify the Directory to Run On (Must be the root containing the .git folder). Defaults to $(pwd)."
	echo "-i         Enable Automatic Removal of Ignored Files"
	echo "-q         Enable Quiet Mode. Only Outputs File Names Ignored By Git Ignore. This setting is ignored if i argument exists."
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
bIgnored=false;
bBackup=true;
sExportFile="./../tmp.Files.log"
vIFS=$IFS;
sIndexFile="./../tmp.Index.log"
sRemoveFile="./../tmp.Remove.log"
sFile=""
sFiles=""

#Build Options
while getopts bcd:e:f:hiq option
do
	case "${option}"
	in
		b) bBackup=false;;
		c) bClean=false;;
		d) sPath=${OPTARG};;
		e) sExportFile=${OPTARG};;
		f) sFile=${OPTARG};;
		h) 
			renderHelp
			exit 0;;
		i) bIgnored=true;;
		q) bQuiet=true;;
	esac
done

if [ -z $sFile ]; then
	while read -t 0 $sData; do
		sFiles="$sFiles"$'\n'"$sData"
	done
fi

#Check that provided directory exists
if ! [ -d $sPath ]; then
	echo "ERROR: Path Not Found Or Is Not A Directory: $sPath"
	echo " "
	renderHelp
	exit 1;
fi

if [ $bBackup != false ]; then
	showMessage "Backing Up..." true
		sDate=$(date +%Y%m%d-%H%i%s)
		tar -zcf "$sPath/../repo-$sDate.tar.gz" $sPath > /dev/null 2>&1
	showMessage "Backing Up...Done!"
fi

showMessage "Entering $sPath"

pushd "${sPath}" > /dev/null
	if ! [ -d .git ]; then
		echo "ERROR: Directory is not a Git Repository"
		echo " "
		renderHelp
		exit 2;
	fi

	#Output Index To Temp File For Faster Processing
	git ls-files > $sIndexFile
		
	# Defining Defaults
	iCount=0
	iTotal=0
	sRemove=""
	
	#Set Argument Separator
	IFS=$'\n'
	
	if [ -z $sFiles ]; then
		if [ -n "$sFile" ]; then
			if ! [ -f $sFile ]; then
				echo "ERROR: File List File Does Not Exist"
				echo " "
				renderHelp
				exit 4;
			fi
			
			showMessage "Loading File List from $sFile..." true
			sFiles=$(cat $sFile);
			showMessage "Loading File List...Done!"
		else
			showMessage "Building File List..." true
			find . -type f > $sExportFile;
			sFiles=$(cat $sExportFile);
			showMessage "Building File List...Done!"
			
			if [ $sExportFile == "./../tmp.Files.log" ]; then
				rm $sExportFile
			fi
		fi
	fi
	
	# Generate Count (Too Many To Pipe)
	if [ $iTotal == 0 ]; then
		for sFile in $sFiles; do
			let iTotal+=1
			showMessage "Counting Files...$iTotal" true
		done;
		showMessage "Counting Files...Done!"
	fi
	
	# Loop Through Files
	for sFile in $sFiles; do
		if [ ${sFile:2:4} == ".git" ]; then
			continue;
		fi
		
		bIncluded=false
		sFound=$(grep -m1 "${sFile:2}" $sIndexFile)
		if [ -z "$sFound" ]; then
			echo $'\n'"${sFile:2}" >> $sRemoveFile
		fi
			
		let iCount+=1
		let iRemaining=$iTotal-$iCount
		showMessage "Comparing To Index...$iRemaining Remaining..." true
	done;
	
	showMessage "Comparing To Index...Done!"
	
	if [ $sIndexFile == "./../tmp.Index.log" ]; then
		rm $sIndexFile;
	fi
	
	sRemove=$(cat $sRemoveFile)
	rm $sRemoveFile
		
	if [ $bIgnored == true ]; then
		iTotal=0
		for sFile in $sRemove; do
			let iTotal+=1
			showMessage "Counting Files to Remove...$iTotal" true
		done;

		showMessage "Counting Files to Remove...Done!"
		iCount=0

		for sFile in $sRemove; do
			let iCount+=1
			
			let iRemaining=$iTotal-$iCount
		
			showMessage "Removing Ignored Files From History...$iRemaining Remaining..."
			if [ $bQuiet ]; then
				git filter-branch --force --index-filter "git rm --cached --ignore-unmatch $sFile" --prune-empty --tag-name-filter cat -- --all > /dev/null 2>&1
				rm -rf .git/refs/original/ > /dev/null 2>&1
				git reflog expire --expire=now --all > /dev/null 2>&1
			else
				git filter-branch --force --index-filter "git rm --cached --ignore-unmatch $sFile" --prune-empty --tag-name-filter cat -- --all
				rm -rf .git/refs/original/ #> /dev/null 2>&1
				git reflog expire --expire=now --all #> /dev/null 2>&1
			fi
		done;
			
		IFS=$vIFS
		showMessage "Removing Ignored Files From History...Done!"
		showMessage "Cleaning Up..." true
		git gc --prune=now > /dev/null 2>&1	
		git gc --aggressive --prune=now > /dev/null 2>&1
		showMessage "Cleaning Up...Done!"
	else
		echo $sRemove
	fi
popd