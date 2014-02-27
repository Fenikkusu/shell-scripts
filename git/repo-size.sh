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
			echo -e "$1"
		fi
	fi
}

#Set Defaults
sPath=$(pwd);
bClean=true;
bQuiet=false;
iMaxSize=0;
bIgnored=true;
vLoad=false;
vSave=false;
bBackup=true;
vIFS=$IFS;
sIndexFile="tmp.Index.log"

let iMaxArgs=$(getconf ARG_MAX)-100

#Build Options
while getopts hcd:qsif:o:b option
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
		f) vLoad=${OPTARG};;
		o) vSave=${OPTARG};;
		b) bBackup=false;;
	esac
done

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
	
	if [ $vLoad != false ]; then
		if ! [ -f $vLoad ]; then
			echo "ERROR Import File Does Not Exist: $vLoad"
			echo " "
			renderHelp
			exit 4;
		fi
	fi
	
	if [ $vLoad == false ]; then
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
	
		iTotal=$(echo "$sObjects" | cut -f 1 -d\ | wc -l | awk '{gsub(/^ +| +$/,"")} {print $0}')
		iCount=0
		let iCols=$(tput cols)-22;
		
		sFiles=""
		IFS=$'\n'
		for sObject in $sObjects; do
			SHA=$(echo "$sObject" | cut -f 1 -d\ )
			
			sIndex=$(grep $SHA $sIndexFile);
			if [ -z "$sIndex" ]; then
				continue
			fi
			
			iSize=$(echo "$sObject" | awk '{print $3}');
			sFile=$(echo "$sIndex" | awk '{print $2}');

			if [ $iMaxSize == 0 -o $iSize -gt $iMaxSize ]; then
				sFiles="$sFiles"$'\n'"$sFile"
			fi
		
			let iCount+=1
			
			#iPercent=$(awk -v c=$iCount -v t=$iTotal 'BEGIN { print c / t }')
			#iColumns=$(awk -v c=$iCols -v p=$iPercent 'BEGIN { print int(c * p) }')
			#iPercent=$(awk -v p=$iPercent 'BEGIN { print int(p * 100) }')
			#iBlankCols=$(awk -v c=$iCols -v f=$iColumns 'BEGIN { print c - f}' )
		

			#if [ $iColumns == "0" ]; then
					#		sEqual=""
			#else
				#	sEqual=$(head -c $iColumns < /dev/zero | tr '\0' '=')
			#fi
			#if [ $iBlankCols == "0" ]; then
				#	sBlank=""
			#else
				#	sBlank=$(head -c $iBlankCols < /dev/zero | tr '\0' ' ')
			#	fi
		
			#showMessage "Processing...[$sEqual$sBlank] $iPercent %" true

			let iRemaining=$iTotal-$iCount
			showMessage "Processing...$iRemaining Items Remaining..." true
		done;
		IFS=$vIFS

		let iCols=$iCols-18
		sBlank=$(head -c $iCols < /dev/zero | tr '\0' ' ')
		showMessage "\rProcessing...Done! $sBlank"
		
		rm $sIndexFile
		
		if [ $vSave != false ]; then
			showMessage "Saving Files List..." true
			echo "$sFiles" > $vSave
			showMessage "\rSaving Files List...Done!"
		fi
	else
		sFiles=$(cat $vLoad);
	fi
	
	if [ $bIgnored ]; then
		git ls-files > $sIndexFile
		
		#iTotal=$(cat $sFiles | wc -l | awk '{gsub(/^ +| +$/,"")} {print $0}')
		#let iCols=$(tput cols)-29;
			#Comparing To Index...[]     %#
		
		#Defaults
		iCount=0
		iTotal=0
		sRemove=""
		IFS=$'\n'
		for sFile in $sFiles; do
			let iTotal+=1
		done;
		for sFile in $sFiles; do
			bIncluded=false
			sFound=$(grep -m1 $sFile $sIndexFile)
			if [ -n "$sFound" ]; then
				sRemove="$sRemove"$'\n'"$sFile"
			fi
			
			let iCount+=1
			
			
			#iPercent=$(awk -v c=$iCount -v t=$iTotal 'BEGIN { print c / t }')
			#iColumns=$(awk -v c=$iCols -v p=$iPercent 'BEGIN { print int(c * p) }')
			#iPercent=$(awk -v p=$iPercent 'BEGIN { print int(p * 100) }')
			#iBlankCols=$(awk -v c=$iCols -v f=$iColumns 'BEGIN { print c - f }' )
		

			#if [ $iColumns == "0" ]; then
				#	sEqual=""
			#else
				#	sEqual=$(head -c $iColumns < /dev/zero | tr '\0' '=')
			#fi
			#if [ $iBlankCols == "0" ]; then
				#	sBlank=""
			#else
				#	sBlank=$(head -c $iBlankCols < /dev/zero | tr '\0' ' ')
			#fi
		
			#showMessage "Comparing To Index...[$sEqual$sBlank] $iPercent %" true
			
			let iRemaining=$iTotal-$iCount
			showMessage "Comparing To Index...$iRemaining Remaining..." true
		done;
		IFS=$vIFS
		let iCols=$iCols+9
		sBlank=$(head -c $iCols < /dev/zero | tr '\0' ' ')
		showMessage "Comparing To Index...Done!$sBlank"
		
		rm $sIndexFile
		
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
				git filter-branch --force --index-filter "git rm --cached --ignore-unmatch $sRemoving" --prune-empty --tag-name-filter cat -- --all #> /dev/null 2>&1
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