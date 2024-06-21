#!/bin/bash

# Run this script to deploy the project on AWS

export AWS_REGION=eu-west-3
export STACK_NAME=webtest2

export STAGE_NAME=v1

# Optional: connect to an existing lambda to implement the API
# (else create a simple lambda as part of the stack)
export USE_EXTERNAL_LAMBDA=true
export EXTERNAL_LAMBDA_ARN="arn:aws:lambda:eu-west-3:637423608549:function:externaltest"

# Optional: custom domain settings.
# Must then update the custom DNS records with the new cloudfront URL.
export USE_CUSTOM_DOMAIN=false
export DOMAIN_NAME=mtest.dev
export DOMAIN_CERT_ARN="define_this"

##################################################################

RAND_ID=$(dd if=/dev/random bs=3 count=4 2>/dev/null \
            | od -An -tx1 | tr -d ' \t\n')
export WEB_BUCKET_NAME="${STACK_NAME}-bucket-${RAND_ID}"

# Prevent terminal output waiting:
export AWS_PAGER=""

source stack.sh $STACK_NAME create $WEB_BUCKET_NAME "stageName=$STAGE_NAME \
    enableCustomDomainName=$USE_CUSTOM_DOMAIN domainName=$DOMAIN_NAME certificateArn=$DOMAIN_CERT_ARN \
    useExistingLambda=$USE_EXTERNAL_LAMBDA existingLambdaArn=$EXTERNAL_LAMBDA_ARN"

echo ""
echo "Waiting for stack creation..."

if [ "$USE_CUSTOM_DOMAIN" != "true" ]; then
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

    export WEBSITE_URL="https://${GATEWAY_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}"
    echo ""
    echo "The website URL is:"
    echo $WEBSITE_URL
    echo ""
else
    CLOUDFRONT_URL=
    while [[ -z $CLOUDFRONT_URL ]]; do
        export CLOUDFRONT_URL=$(aws apigateway get-domain-names --no-paginate | \
        python3 -c \
"import sys, json
for item in json.load(sys.stdin)['items']:
    if item['domainName'] == '$DOMAIN_NAME':
        print(item['distributionDomainName'])")
        sleep 1
    done

    echo ""
    echo "The CloudFront URL is:"
    echo $CLOUDFRONT_URL
    echo ""
fi

echo "Upload website files to the following S3 bucket:"
echo "WEB_BUCKET_NAME = $WEB_BUCKET_NAME"
echo ""
