# DO NOT RUN THIS ENTIRE SCRIPT AT ONCE
# Each step must be ran separately

##########################################
# Step 1a: Get a list of all GLACIER files
# Pros: Only need to run once
# Cons: Glacier.txt can be too big to open
##########################################

#!/bin/bash
BUCKET="s3-bucket-name"
PREFIX="foldername"
PROFILE="awscliprofile"
MAX_ITEM=100000

var=0
NEXT_TOKEN=0
while true; do

	var=$((var+1))

	echo "Iteration #$var - Next token: $NEXT_TOKEN"

	aws s3api list-objects \
	--bucket $BUCKET \
	--prefix $PREFIX \
	--profile $PROFILE \
	--max-item $MAX_ITEM \
	--starting-token $NEXT_TOKEN > temp

	awk '/GLACIER/{getline; print}' temp >> glacier.txt

	NEXT_TOKEN=$(cat temp | grep NextToken | awk '{print $2}' | sed 's/\("\|",\)//g')
	if [ ${#NEXT_TOKEN} -le 5 ]; then
		echo "No more files..."
		echo "Next token: $NEXT_TOKEN"
		break
		rm temp
	fi
	rm temp
done
echo "Exiting."

##########################################
# Step 1b: Get lists of all GLACIER files
# Pros: Files are small
# Cons: Need to run multiple times and 
#       could end up with error
##########################################

aws s3api list-objects --bucket my-bucket --query 'Contents[?StorageClass==`GLACIER`]' --profile awscli --max-item 100000 > glacier.txt
cat glacier.txt | grep "Key" > glacier.txt

##########################################
# Step 2: Use a text editor to replace text
#         and get lists of GLACIER files
##########################################

# Each line in glacier.txt has this format: ["Key": "path/to/file.ext",]
# Use a text editor to replace ["Key": "] and [",] with blank

##########################################
# Step 3: Restore all GLACIER files
# Usage: ./restore.sh part-1.txt 0
# Note: Use {Tier=Expedited} for faster restore
#	Run in parallel for multiple files
##########################################

fileName="$1" # File containing only S3 object key
var="$2" # Count

BUCKET="s3-bucket-name"
PREFIX="foldername"
PROFILE="awscliprofile"

while read p; do
  aws s3api restore-object --bucket $BUCKET --restore-request "Days=30,GlacierJobParameters={Tier=Bulk}" --key "$p" --profile $PROFILE
  var=$((var+1))
  echo "#$var ... $p"
done < $fileName

##########################################
# Step 4: Replace GLACIER with STANDARD
#         by copy and overwrite
# Usage: ./copy.sh part-1.txt 0
# Note: Must wait for step 3 to finish,
#       check if last file is restored 
#       before running this script
#	Run in parallel for multiple files
##########################################

fileName="$1" # File containing only S3 object key
var="$2" # Count

BUCKET="s3-bucket-name"
PREFIX="foldername"
PROFILE="awscliprofile"

while read p; do
  aws s3api copy-object --bucket $BUCKET --copy-source "$BUCKET/$p" --key "$p" --query "CopyObjectResult.{LastModified}" --profile $PROFILE
  var=$((var+1))
  echo "#$var ... $p"
done < $fileName

