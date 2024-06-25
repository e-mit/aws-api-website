#!/bin/bash

# Run this script to deploy the project on AWS

export AWS_REGION=eu-west-3
export STACK_NAME=webtest2
export STAGE_NAME=v1

# Optional: connect to an existing lambda to implement the API
# (else create a simple lambda as part of the stack)
export USE_EXTERNAL_LAMBDA=false
export EXTERNAL_LAMBDA_ARN="put ARN here"

# Optional: custom domain settings.
# Must then update the custom DNS records with the new cloudfront URL.
export USE_CUSTOM_DOMAIN=false
export DOMAIN_NAME=mtest.dev
export DOMAIN_CERT_ARN="put ARN here"

# Optional: enable captcha protection for any API paths containing a chosen string
# Also choose how long the valid captcha lasts.
export CAPTCHA_PATH_STRING="/captcha"
export CAPTCHA_TIME_SECONDS=60

##################################################################

RAND_ID=$(dd if=/dev/random bs=3 count=4 2>/dev/null \
            | od -An -tx1 | tr -d ' \t\n')
export WEB_BUCKET_NAME="${STACK_NAME}-bucket-${RAND_ID}"

# Prevent terminal output waiting:
export AWS_PAGER=""

source stack.sh $STACK_NAME create $WEB_BUCKET_NAME "stageName=$STAGE_NAME \
    enableCustomDomainName=$USE_CUSTOM_DOMAIN domainName=$DOMAIN_NAME certificateArn=$DOMAIN_CERT_ARN \
    useExistingLambda=$USE_EXTERNAL_LAMBDA existingLambdaArn=$EXTERNAL_LAMBDA_ARN \
    captchaPathString=$CAPTCHA_PATH_STRING captchaImmunitySeconds=$CAPTCHA_TIME_SECONDS"

echo ""

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

WEB_ACL_ARN=$(aws wafv2 list-web-acls --scope REGIONAL | \
    python3 -c \
"import sys, json
for item in json.load(sys.stdin)['WebACLs']:
    if item['Name'] == '$STACK_NAME-web-acl':
        print(item['ARN'])")

GATEWAY_ARN="arn:aws:apigateway:$AWS_REGION::/restapis/$GATEWAY_ID/stages/${STAGE_NAME}"

echo "Setting up captcha protection: this can take several minutes..."
CAPTCHA_CMD="aws wafv2 associate-web-acl --web-acl-arn $WEB_ACL_ARN --resource-arn $GATEWAY_ARN"
until $CAPTCHA_CMD &> /dev/null; do
    sleep 10
done
echo "Done."

if [ "$USE_CUSTOM_DOMAIN" != "true" ]; then

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
