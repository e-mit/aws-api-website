# AWS API Website

This project creates an API Gateway which serves a public REST API and a public static website, hosted on AWS.

All resources are deployed in a single CloudFormation stack, which can be created or deleted via single commands.

Optional features:
- Configure a custom domain name for the gateway URL.
- Connect to an existing lambda to implement the API, rather than create a new one.
- Restrict access to any URL path containing a chosen string by requiring a CAPTCHA.


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

Website paths map to simulated S3 folders by putting slashes in ```<public file name>```. For example, uploading a file named "a/b/c.html" will make it accessible at ```{GATEWAY_URL}/{stage}/static/a/b/c.html```.


## To Delete All Resources

Run ```./stack.sh $STACK_NAME delete $WEB_BUCKET_NAME```

This will also delete the S3 bucket contents.


## CAPTCHA support

Any URL path containing ```CAPTCHA_PATH_STRING``` will require a CAPTCHA to be solved before accessing. After being solved, access will be allowed for ```CAPTCHA_TIME_SECONDS```.

Accessing the URL directly will return a 405 error and an Amazon-generated challenge page. Solving the captcha then forwards the browser to the URL.

Alternatively, the CAPTCHA can be custom-generated in javascript, as demonstrated in test_captcha.html.
This requires manual setup as follows:
1. Go to AWS WAF > "application integration" in AWS console
2. Copy the captcha integration javascript tag, and put it in the page head
3. Generate an apiKey for the domain, and paste into the javascript code

Note: the CAPTCHA setup method is the same even if using a custom domain name (CloudFront involvement has no effect).


## Optional: Using a Custom Domain Name

### Certificate setup: manual process

1. Sign in to the AWS Certificate Manager console **and set the region to us-east-1** (mandatory region).
2. Choose "Request a certificate".
3. Enter the custom domain name for the API in "Domain name".
4. Choose "Review, request and confirm".
5. In AWS Certificate Manager, copy the CNAME name/values of the pending certificate and paste into the domain provider's system as a new CNAME record. The certificate will remain pending until the DNS updates (up to 48 hours).
6. Copy the certificate ARN for later use.

### Stack creation

1. Run ```source setup.sh``` as usual, but set ```USE_CUSTOM_DOMAIN=true``` and provide the domain name and certificate ARN.
2. An intermediate (cloudfront) URL is created by AWS. Obtain this URL and use it to create a new CNAME record (for a subdomain) or a new ALIAS record (for the root domain) in the domain provider's system.
3. Wait for the DNS to update.

### Important notes

- This process disables the usual API Gateway URL, so the website can only be accessed via the custom domain name.
- The intermediate cloudfront URL **can** be accessed directly, as a test, **but must have the request ```Host``` header set to the custom domain**. Therefore it cannot be tested with simple web browser use.
