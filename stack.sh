#!/bin/bash

# A script to create a Cloudformation stack.

# Run this script like:
# ./stack.sh <stack name> <command> <bucket name>

# Where "command" is one of the following:
entryFuncs=("delete" "create")

# "delete": Delete the existing stack and all of its resources.
# "create": Create the stack. An error occurs if a stack already
#           exists with the provided name, and no update occurs.

############################################################

STACK_NAME=$1
WEB_BUCKET_NAME=$3

if [[ -z $STACK_NAME ]]; then
    echo ERROR: Please set STACK_NAME
    return 1
else
    # Convert to lower-case
    STACK_NAME_LOWER="$(echo $STACK_NAME | tr '[A-Z]' '[a-z]')"
fi

if [[ -z $WEB_BUCKET_NAME ]]; then
    echo ERROR: Please set WEB_BUCKET_NAME
    return 1
fi

# Prevent terminal output waiting:
export AWS_PAGER=""

_make_names() {
    RAND_ID=$(dd if=/dev/random bs=3 count=6 2>/dev/null \
              | od -An -tx1 | tr -d ' \t\n')
    TEMP_BUCKET_NAME="${STACK_NAME_LOWER}-bucket-${RAND_ID}"
}

_delete_files() {
    rm -f out.yml *.zip
}

delete() {
    _delete_files
    _make_names
    echo "Deleting stack $STACK_NAME and its resources..."

    # First must delete the bucket:
    aws s3 rb --force s3://$WEB_BUCKET_NAME &> /dev/null

    aws cloudformation delete-stack --stack-name $STACK_NAME


    STACK_DELETED=
    while [[ -z $STACK_DELETED ]]; do
        export STACK_DELETED=$(aws aws cloudformation list-stacks | \
        python3 -c \
"import sys, json
complete = True
for item in json.load(sys.stdin)['StackSummaries']:
    if item['StackName'] == '$STACK_NAME' and item['StackStatus'] != 'DELETE_COMPLETE':
        complete = False
if complete:
    print('true')")
        sleep 1
    done

    echo "Deleted $STACK_NAME"
}

create() {
    _make_names
    echo "Creating $STACK_NAME..."

    aws s3 mb s3://$TEMP_BUCKET_NAME
    echo Made temporary S3 bucket $TEMP_BUCKET_NAME

    aws cloudformation package \
    --template-file template.yml \
    --s3-bucket $TEMP_BUCKET_NAME \
    --output-template-file out.yml &> /dev/null

    aws cloudformation deploy \
    --template-file out.yml \
    --stack-name $STACK_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides stackName=$STACK_NAME bucketName=$WEB_BUCKET_NAME

    if [[ "$?" -ne 0 ]]; then
        aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME
    fi

    aws s3 rb --force s3://$TEMP_BUCKET_NAME
    echo Deleted the temporary S3 bucket

    # upload the static website files to the bucket:
    aws s3 cp index.html s3://${WEB_BUCKET_NAME}/index.html
    aws s3 cp error.html s3://${WEB_BUCKET_NAME}/error.html
}

################################################

ok=0
for i in "${entryFuncs[@]}"
do
    if [ "$i" == "$2" ]; then
        echo "Executing $i()"
        $i
        ok=1
    fi
done

if (( ok == 0 )); then
    echo "Error: command not recognised"
fi
