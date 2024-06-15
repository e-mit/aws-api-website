#!/bin/bash

# Run this script to deploy the project on AWS

export AWS_REGION=eu-west-3
export STACK_NAME=webtest1

##################################################################

RAND_ID=$(dd if=/dev/random bs=3 count=4 2>/dev/null \
            | od -An -tx1 | tr -d ' \t\n')
export WEB_BUCKET_NAME="${STACK_NAME}-bucket-${RAND_ID}"

# Prevent terminal output waiting:
export AWS_PAGER=""

source stack.sh $STACK_NAME create $WEB_BUCKET_NAME

echo ""
echo "Waiting for stack creation..."

GATEWAY_ID=
while [[ -z $GATEWAY_ID ]]; do
    export GATEWAY_ID=$(aws apigateway get-rest-apis --no-paginate | \
    python3 -c \
"import sys, json
for item in json.load(sys.stdin)['items']:
    if item['name'] == '$STACK_NAME-api-gateway':
        print(item['id'])")
    sleep 1
done

export GATEWAY_URL="https://${GATEWAY_ID}.execute-api.${AWS_REGION}.amazonaws.com/"

echo ""
echo "The API Gateway URL is:"
echo $GATEWAY_URL
echo ""
# Note: must go to GATEWAY_URL/<stage (e.g. v1)> to access the actual website
