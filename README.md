# AWS API Website

This project creates an API Gateway which serves a public REST API and a public static website, hosted on AWS.

All resources are deployed in a single CloudFormation stack, which can be created or deleted via single commands.


## Static Website

A private S3 bucket is created, which hosts files to form a public static website

The website's default homepage is accessed via the root URL: ```{GATEWAY_URL}/{stage}```, where the default stage is "v1". This page is provided by the "index.html" file in the S3 bucket.

All other website files are accessed via ```{GATEWAY_URL}/{stage}/static/{filename}```, where "filename" is the name used for the file in the S3 bucket. The static root ```/static/``` also redirects to index.html.

Accessing non-existent files will not result in a 404 error but instead will give a 200 status with an XML error message. Accessing paths other than ```/static/{filename}``` will give a 403 forbidden error.

Static website files can be uploaded to the S3 bucket easily via the AWS CLI, or the AWS web console.


## REST API

A lambda function provides simple demonstration API capability.

The REST API can be accessed with any REST method and any path at ```{GATEWAY_URL}/{stage}/api/{path}```, where the default stage is "v1".


## To Deploy

Run ```source setup.sh```

Add extra website files with:
```aws s3 cp <local file name> s3://${WEB_BUCKET_NAME}/<public file name>```


## To Delete All Resources

Run ```/stack.sh $STACK_NAME delete $WEB_BUCKET_NAME```

This will also delete the S3 bucket contents.
