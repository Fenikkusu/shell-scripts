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
			echo -e "$1"
		fi
	fi
}

#Set Defaults
sPath=$(pwd);
bIgnored=false;
vIFS=$IFS;
sIndexFile="tmp.Index.log"
sFile=""
sFiles=""

#Build Options
while getopts hcd:f:iq option
do
	case "${option}"
	in
		b) bBackup=false;;
		c) bClean=false;;
		d) sPath=${OPTARG};;
		f) sFile=${OPTARG};;
		h) 
			renderHelp
			exit 0;;
		i) bIgnored=true;;
		q) bQuiet=true;;
	esac
done

if [ -z $sFile ]; then
	while read data; do
		$sFiles=""
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
		if [ -n $sFile ]; then
			sFiles=$(cat $sFile);	
		else
			for sFile in $(find . -type f); do
				sFiles="$sFiles"$'\n'"$sFile"
			done
		fi
	fi
	
	# Generate Count (Too Many To Pipe)
	for sFile in $sFiles; do
		let iTotal+=1
	done;
	
	# Loop Through Files
	for sFile in $sFiles; do
		bIncluded=false
		sFound=$(grep -m1 $sFile $sIndexFile)
		if [ -n "$sFound" ]; then
			sRemove="$sRemove"$'\n'"$sFile"
		fi
			
			
		let iCount+=1
		let iRemaining=$iTotal-$iCount
		showMessage "Comparing To Index...$iRemaining Remaining..." true
	done;
	
	# Reseting Argument Spearator
	IFS=$vIFS
	
	let iCols=$iCols+9
	sBlank=$(head -c $iCols < /dev/zero | tr '\0' ' ')
	showMessage "Comparing To Index...Done!$sBlank"
		
	if [ -n "$sRemove" ]; then
			iTotal=$(echo "$sRemove" | wc -l | awk '{gsub(/^ +| +$/,"")} {print $0}')
			let iCols=$(tput cols)-46;
				#"Removing Ignored Files From History...[]     "
			iCount=0
			sRemoving=""
			IFS=$'\n'
			for sFile in $sRemove; do
				let iCount+=1
				
				let iRemaining=$iTotal-$iCount
			
				showMessage "Removing Ignored Files From History...$iRemaining Remaining..." true
				git filter-branch --force --index-filter "git rm --cached --ignore-unmatch $sRemoving" --prune-empty --tag-name-filter cat -- --all | {
					while read sLine; do
						if [ $sLine =~ "\(([A-Z]+)\/([A-Z]+)\)" ]; then
								
						fi
					done
				}
				
				rm -rf .git/refs/original/ #> /dev/null 2>&1
				git reflog expire --expire=now --all #> /dev/null 2>&1
			done;
			
			IFS=$vIFS
			let iCols=$iCols+3
			sBlank=$(head -c $iCols < /dev/zero | tr '\0' ' ')
			showMessage "Removing Ignored Files From History...Done!$sBlank"
			showMessage "Cleaning Up..." true
				git gc --prune=now > /dev/null 2>&1
				git gc --aggressive --prune=now > /dev/null 2>&1
			showMessage "Cleaning Up...Done!"
		fi
	fi