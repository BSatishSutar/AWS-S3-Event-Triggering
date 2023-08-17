#!/bin/bash

set -x

# Storing the AWS account ID in a variable
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)

# Printing the AWS account ID from the variable
echo "AWS Account ID: $aws_account_id"

# Setting AWS region, bucket name, lambda function, IAM role name and email address
aws_region="us-east-1"
bucket_name="abhishek-ultimate-bucket"
lambda_func_name="s3-lambda-function"
role_name="s3-lambda-sns"
email_address="zyz@gmail.com"

# Creating IAM Role for the project, This IAM Role is created with all permissions given to: Lambda function - S3 Bucket - SNS Topic
role_response=$(aws iam create-role --role-name s3-lambda-sns --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": [
         "lambda.amazonaws.com",
         "s3.amazonaws.com",
         "sns.amazonaws.com"
      ]
    }
  }]
}')

# Extract the role ARN from the JSON response and store it in a variable, here 'jq' is a JSON parser
role_arn=$(echo "$role_response" | jq -r '.Role.Arn')

# Printing the IAM role ARN that was created
echo "Role ARN: $role_arn"

# Attaching Permissions to the IAM Role
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# Create the S3 bucket and capture the output in a variable
bucket_output=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region")

# Print the output from the variable i.e. printing the S3 bucket created
echo "Bucket creation output: $bucket_output"

# Uploading/Copying a sample text file to the S3 bucket created above, this file is part of this repo
aws s3 cp ./example_file.txt s3://"$bucket_name"/example_file.txt

# Create a Zip file to upload Lambda Function
zip -r s3-lambda-function.zip ./s3-lambda-function

sleep 5
# Create a Lambda function
aws lambda create-function \
  --region "$aws_region" \
  --function-name $lambda_func_name \
  --runtime "python3.8" \
  --handler "s3-lambda-function/s3-lambda-function.lambda_handler" \
  --memory-size 128 \
  --timeout 30 \
  --role "arn:aws:iam::$aws_account_id:role/$role_name" \
  --zip-file "fileb://./s3-lambda-function.zip"

# Adding Permissions to S3 Bucket to invoke Lambda function
aws lambda add-permission \
  --function-name "$lambda_func_name" \
  --statement-id "s3-lambda-sns" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$bucket_name"

# Create an S3 event to trigger the Lambda function
LambdaFunctionArn="arn:aws:lambda:us-east-1:$aws_account_id:function:s3-lambda-function"
aws s3api put-bucket-notification-configuration \
  --region "$aws_region" \
  --bucket "$bucket_name" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
        "LambdaFunctionArn": "'"$LambdaFunctionArn"'",
        "Events": ["s3:ObjectCreated:*"]
    }]
}'

# Creating an SNS topic and saving the topic ARN into a variable
topic_arn=$(aws sns create-topic --name s3-lambda-sns --output json | jq -r '.TopicArn')

# Printing the TopicArn
echo "SNS Topic ARN: $topic_arn"

# Trigger SNS Topic using Lambda Function


# Adding SNS publish permission to the Lambda Function
aws sns subscribe \
  --topic-arn "$topic_arn" \
  --protocol email \
  --notification-endpoint "$email_address"

# Publish SNS
aws sns publish \
  --topic-arn "$topic_arn" \
  --subject "A new object created in s3 bucket" \
  --message "Hello from Abhishek.Veeramalla YouTube channel, Learn DevOps Zero to Hero for Free"


