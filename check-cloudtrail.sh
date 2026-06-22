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

SERVICE="CLOUDTRAIL"

create_report_dir

REPORT_FILE="reports/cloudtrail-report.csv"
HTML_FILE="reports/cloudtrail-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# CLOUDTRAIL CONFIGURATION
###############################################################################

TRAILS=$(aws cloudtrail describe-trails \
    --query 'trailList[*].Name' \
    --output text 2>/dev/null)

if [[ -z "$TRAILS" ]]
then
    write_result global CLOUDTRAIL CLOUDTRAIL_ENABLED Account FAIL CRITICAL \
    "No CloudTrail trail configured"

else
    write_result global CLOUDTRAIL CLOUDTRAIL_ENABLED Account PASS CRITICAL \
    "CloudTrail configured"
fi

###############################################################################
# TRAIL CHECKS
###############################################################################

for TRAIL in $TRAILS
do

    REGION=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].HomeRegion' \
        --output text 2>/dev/null)

    MULTI_REGION=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].IsMultiRegionTrail' \
        --output text 2>/dev/null)

    if [[ "$MULTI_REGION" == "True" ]]
    then
        write_result "$REGION" CLOUDTRAIL MULTI_REGION_TRAIL "$TRAIL" PASS HIGH \
        "Multi-region trail enabled"
    else
        write_result "$REGION" CLOUDTRAIL MULTI_REGION_TRAIL "$TRAIL" FAIL HIGH \
        "Single-region trail"
    fi

    LOGGING=$(aws cloudtrail get-trail-status \
        --name "$TRAIL" \
        --query 'IsLogging' \
        --output text 2>/dev/null)

    if [[ "$LOGGING" == "True" ]]
    then
        write_result "$REGION" CLOUDTRAIL IS_LOGGING "$TRAIL" PASS CRITICAL \
        "Trail logging enabled"
    else
        write_result "$REGION" CLOUDTRAIL IS_LOGGING "$TRAIL" FAIL CRITICAL \
        "Trail logging disabled"
    fi

    VALIDATION=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].LogFileValidationEnabled' \
        --output text 2>/dev/null)

    if [[ "$VALIDATION" == "True" ]]
    then
        write_result "$REGION" CLOUDTRAIL LOG_FILE_VALIDATION "$TRAIL" PASS HIGH \
        "Log file validation enabled"
    else
        write_result "$REGION" CLOUDTRAIL LOG_FILE_VALIDATION "$TRAIL" FAIL HIGH \
        "Log file validation disabled"
    fi

    S3_BUCKET=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].S3BucketName' \
        --output text 2>/dev/null)

    if [[ -n "$S3_BUCKET" && "$S3_BUCKET" != "None" ]]
    then
        write_result "$REGION" CLOUDTRAIL S3_LOGGING_BUCKET "$TRAIL" PASS HIGH \
        "Logs delivered to $S3_BUCKET"
    else
        write_result "$REGION" CLOUDTRAIL S3_LOGGING_BUCKET "$TRAIL" FAIL HIGH \
        "No S3 bucket configured"
    fi

    KMS_KEY=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].KmsKeyId' \
        --output text 2>/dev/null)

    if [[ -n "$KMS_KEY" && "$KMS_KEY" != "None" ]]
    then
        write_result "$REGION" CLOUDTRAIL KMS_ENCRYPTION "$TRAIL" PASS MEDIUM \
        "KMS encryption enabled"
    else
        write_result "$REGION" CLOUDTRAIL KMS_ENCRYPTION "$TRAIL" FAIL MEDIUM \
        "KMS encryption not enabled"
    fi

        CLOUDWATCH_LOG_GROUP=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].CloudWatchLogsLogGroupArn' \
        --output text 2>/dev/null)

    if [[ -n "$CLOUDWATCH_LOG_GROUP" && "$CLOUDWATCH_LOG_GROUP" != "None" ]]
    then
        write_result "$REGION" CLOUDTRAIL CLOUDWATCH_LOGS "$TRAIL" PASS MEDIUM \
        "CloudWatch Logs integration enabled"
    else
        write_result "$REGION" CLOUDTRAIL CLOUDWATCH_LOGS "$TRAIL" FAIL MEDIUM \
        "CloudWatch Logs integration disabled"
    fi

    SNS_TOPIC=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].SnsTopicARN' \
        --output text 2>/dev/null)

    if [[ -n "$SNS_TOPIC" && "$SNS_TOPIC" != "None" ]]
    then
        write_result "$REGION" CLOUDTRAIL SNS_NOTIFICATION "$TRAIL" PASS LOW \
        "SNS notification configured"
    else
        write_result "$REGION" CLOUDTRAIL SNS_NOTIFICATION "$TRAIL" FAIL LOW \
        "SNS notification not configured"
    fi

    GLOBAL_EVENTS=$(aws cloudtrail describe-trails \
        --trail-name-list "$TRAIL" \
        --query 'trailList[0].IncludeGlobalServiceEvents' \
        --output text 2>/dev/null)

    if [[ "$GLOBAL_EVENTS" == "True" ]]
    then
        write_result "$REGION" CLOUDTRAIL GLOBAL_SERVICE_EVENTS "$TRAIL" PASS HIGH \
        "Global service events enabled"
    else
        write_result "$REGION" CLOUDTRAIL GLOBAL_SERVICE_EVENTS "$TRAIL" FAIL HIGH \
        "Global service events disabled"
    fi

    MANAGEMENT_EVENTS=$(aws cloudtrail get-event-selectors \
        --trail-name "$TRAIL" \
        --query 'EventSelectors[0].IncludeManagementEvents' \
        --output text 2>/dev/null)

    if [[ "$MANAGEMENT_EVENTS" == "True" ]]
    then
        write_result "$REGION" CLOUDTRAIL MANAGEMENT_EVENTS "$TRAIL" PASS HIGH \
        "Management events captured"
    else
        write_result "$REGION" CLOUDTRAIL MANAGEMENT_EVENTS "$TRAIL" FAIL HIGH \
        "Management events not captured"
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
    CLOUDTRAIL \
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
echo "CloudTrail Audit Complete"


