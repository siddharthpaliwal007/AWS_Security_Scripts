#!/bin/bash
set -uo pipefail

if [[ ! -f "./bootstrap.sh" ]]
then
    echo
    echo "ERROR: bootstrap.sh not found"
    echo
    exit 1
fi

if [[ ! -f "./config.conf" ]]
then
    echo
    echo "Bootstrap not initialized. Running ./bootstrap.sh"
    echo

    chmod +x bootstrap.sh
    ./bootstrap.sh

    if [[ ! -f "./config.conf" ]]
    then
        echo
        echo "ERROR: bootstrap failed"
        echo
        exit 1
    fi
fi

source ./common.sh
source ./config.conf

SERVICE="LAMBDA"

create_report_dir

REPORT_FILE="reports/lambda-report.csv"
HTML_FILE="reports/lambda-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# CLOUDTRAIL COVERAGE
###############################################################################

TRAILS=$(aws cloudtrail describe-trails \
    --query 'trailList[*].Name' \
    --output text 2>/dev/null)

if [[ -n "$TRAILS" ]]
then
    write_result global LAMBDA CLOUDTRAIL_COVERAGE Account PASS HIGH \
    "CloudTrail enabled"
else
    write_result global LAMBDA CLOUDTRAIL_COVERAGE Account FAIL HIGH \
    "CloudTrail not enabled"
fi

###############################################################################
# LAMBDA FUNCTIONS
###############################################################################

FUNCTIONS=$(aws lambda list-functions \
    --query 'Functions[*].FunctionName' \
    --output text 2>/dev/null)

for FUNCTION in $FUNCTIONS
do

    REGION="$DEFAULT_REGION"

###############################################################################
# CLOUDWATCH LOGS
###############################################################################

    LOG_GROUP=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/lambda/$FUNCTION" \
        --query 'logGroups[0].logGroupName' \
        --output text 2>/dev/null)

    if [[ -n "$LOG_GROUP" && "$LOG_GROUP" != "None" ]]
    then
        write_result "$REGION" LAMBDA CLOUDWATCH_LOGS "$FUNCTION" PASS HIGH \
        "CloudWatch log group exists"
    else
        write_result "$REGION" LAMBDA CLOUDWATCH_LOGS "$FUNCTION" FAIL HIGH \
        "CloudWatch log group not found"
    fi

###############################################################################
# X-RAY TRACING
###############################################################################

    TRACING=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION" \
        --query 'TracingConfig.Mode' \
        --output text 2>/dev/null)

    if [[ "$TRACING" == "Active" ]]
    then
        write_result "$REGION" LAMBDA XRAY_TRACING "$FUNCTION" PASS LOW \
        "X-Ray tracing enabled"
    else
        write_result "$REGION" LAMBDA XRAY_TRACING "$FUNCTION" FAIL LOW \
        "X-Ray tracing disabled"
    fi

###############################################################################
# DEAD LETTER QUEUE
###############################################################################

    DLQ=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION" \
        --query 'DeadLetterConfig.TargetArn' \
        --output text 2>/dev/null)

    if [[ -n "$DLQ" && "$DLQ" != "None" ]]
    then
        write_result "$REGION" LAMBDA DLQ_CONFIGURED "$FUNCTION" PASS LOW \
        "Dead letter queue configured"
    else
        write_result "$REGION" LAMBDA DLQ_CONFIGURED "$FUNCTION" FAIL LOW \
        "Dead letter queue not configured"
    fi

###############################################################################
# VPC CONFIGURATION
###############################################################################

    VPC_ID=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION" \
        --query 'VpcConfig.VpcId' \
        --output text 2>/dev/null)

    if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]
    then
        write_result "$REGION" LAMBDA VPC_CONFIGURED "$FUNCTION" PASS LOW \
        "Lambda attached to VPC"
    else
        write_result "$REGION" LAMBDA VPC_CONFIGURED "$FUNCTION" FAIL LOW \
        "Lambda not attached to VPC"
    fi

###############################################################################
# RESERVED CONCURRENCY
###############################################################################

    CONCURRENCY=$(aws lambda get-function \
        --function-name "$FUNCTION" \
        --query 'Concurrency.ReservedConcurrentExecutions' \
        --output text 2>/dev/null)

    if [[ -n "$CONCURRENCY" && "$CONCURRENCY" != "None" ]]
    then
        write_result "$REGION" LAMBDA RESERVED_CONCURRENCY "$FUNCTION" PASS LOW \
        "Reserved concurrency configured"
    else
        write_result "$REGION" LAMBDA RESERVED_CONCURRENCY "$FUNCTION" FAIL LOW \
        "Reserved concurrency not configured"
    fi

###############################################################################
# ENVIRONMENT VARIABLES
###############################################################################

    ENV_VARS=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION" \
        --query 'Environment.Variables' \
        --output text 2>/dev/null)

    if [[ -n "$ENV_VARS" && "$ENV_VARS" != "None" ]]
    then
        write_result "$REGION" LAMBDA ENVIRONMENT_VARIABLES "$FUNCTION" PASS MEDIUM \
        "Environment variables configured"
    else
        write_result "$REGION" LAMBDA ENVIRONMENT_VARIABLES "$FUNCTION" FAIL MEDIUM \
        "No environment variables configured"
    fi

###############################################################################
# FUNCTION URL
###############################################################################

    FUNCTION_URL=$(aws lambda get-function-url-config \
        --function-name "$FUNCTION" \
        --query 'AuthType' \
        --output text 2>/dev/null)

    if [[ "$FUNCTION_URL" == "NONE" ]]
    then
        write_result "$REGION" LAMBDA PUBLIC_FUNCTION_URL "$FUNCTION" FAIL CRITICAL \
        "Function URL publicly accessible"
    else
        write_result "$REGION" LAMBDA PUBLIC_FUNCTION_URL "$FUNCTION" PASS CRITICAL \
        "No public Function URL"
    fi

###############################################################################
# ADMINISTRATOR ACCESS ROLE
###############################################################################

    ROLE_NAME=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION" \
        --query 'Role' \
        --output text 2>/dev/null | awk -F'/' '{print $NF}')

    ADMIN_POLICY=$(aws iam list-attached-role-policies \
        --role-name "$ROLE_NAME" \
        --query "AttachedPolicies[?PolicyName=='AdministratorAccess'].PolicyName" \
        --output text 2>/dev/null)

    if [[ "$ADMIN_POLICY" == "AdministratorAccess" ]]
    then
        write_result "$REGION" LAMBDA ADMIN_ROLE "$FUNCTION" FAIL HIGH \
        "Execution role has AdministratorAccess"
    else
        write_result "$REGION" LAMBDA ADMIN_ROLE "$FUNCTION" PASS HIGH \
        "Execution role does not have AdministratorAccess"
    fi

###############################################################################
# CODE SIGNING
###############################################################################

    CODE_SIGNING=$(aws lambda get-function-code-signing-config \
        --function-name "$FUNCTION" \
        --query 'CodeSigningConfigArn' \
        --output text 2>/dev/null)

    if [[ -n "$CODE_SIGNING" && "$CODE_SIGNING" != "None" ]]
    then
        write_result "$REGION" LAMBDA CODE_SIGNING "$FUNCTION" PASS LOW \
        "Code signing enabled"
    else
        write_result "$REGION" LAMBDA CODE_SIGNING "$FUNCTION" FAIL LOW \
        "Code signing not enabled"
    fi

done

###############################################################################
# HTML REPORT
###############################################################################

generate_html "$REPORT_FILE" "$HTML_FILE"

###############################################################################
# S3 UPLOAD
###############################################################################

if validate_bucket
then

    upload_reports \
    LAMBDA \
    "$REPORT_FILE" \
    "$HTML_FILE"

else

    echo
    echo "ERROR: Report upload skipped"
    echo
    exit 1

fi

###############################################################################
# COMPLETE
###############################################################################

echo
echo "CSV Report : $REPORT_FILE"
echo "HTML Report: $HTML_FILE"
echo
echo "Lambda Audit Complete"
