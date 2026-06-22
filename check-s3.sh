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

SERVICE="S3"

create_report_dir

REPORT_FILE="reports/s3-report.csv"
HTML_FILE="reports/s3-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# ACCOUNT PUBLIC ACCESS BLOCK
###############################################################################

ACCOUNT_PAB=$(aws s3control get-public-access-block \
    --account-id "$ACCOUNT_ID" \
    --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
    --output text 2>/dev/null)

if echo "$ACCOUNT_PAB" | grep -q "True.*True.*True.*True"
then
    write_result global S3 PUBLIC_ACCESS_BLOCK Account PASS CRITICAL \
    "Account-level public access block enabled"
else
    write_result global S3 PUBLIC_ACCESS_BLOCK Account FAIL CRITICAL \
    "Account-level public access block not fully enabled"
fi

###############################################################################
# BUCKET CHECKS
###############################################################################

BUCKETS=$(aws s3api list-buckets \
    --query 'Buckets[*].Name' \
    --output text 2>/dev/null)

for BUCKET in $BUCKETS
do

    REGION=$(aws s3api get-bucket-location \
        --bucket "$BUCKET" \
        --query 'LocationConstraint' \
        --output text 2>/dev/null)

    [[ "$REGION" == "None" ]] && REGION="us-east-1"

    PUBLIC=$(aws s3api get-bucket-policy-status \
        --bucket "$BUCKET" \
        --query 'PolicyStatus.IsPublic' \
        --output text 2>/dev/null)

    if [[ "$PUBLIC" == "True" ]]
    then
        write_result "$REGION" S3 PUBLIC_BUCKET "$BUCKET" FAIL CRITICAL \
        "Bucket is public"
    else
        write_result "$REGION" S3 PUBLIC_BUCKET "$BUCKET" PASS CRITICAL \
        "Bucket is not public"
    fi

    ENCRYPTION=$(aws s3api get-bucket-encryption \
        --bucket "$BUCKET" \
        --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
        --output text 2>/dev/null)

    if [[ -n "$ENCRYPTION" && "$ENCRYPTION" != "None" ]]
    then
        write_result "$REGION" S3 DEFAULT_ENCRYPTION "$BUCKET" PASS HIGH \
        "Default encryption enabled"
    else
        write_result "$REGION" S3 DEFAULT_ENCRYPTION "$BUCKET" FAIL HIGH \
        "Default encryption not enabled"
    fi

    VERSIONING=$(aws s3api get-bucket-versioning \
        --bucket "$BUCKET" \
        --query 'Status' \
        --output text 2>/dev/null)

    if [[ "$VERSIONING" == "Enabled" ]]
    then
        write_result "$REGION" S3 VERSIONING "$BUCKET" PASS MEDIUM \
        "Versioning enabled"
    else
        write_result "$REGION" S3 VERSIONING "$BUCKET" FAIL MEDIUM \
        "Versioning disabled"
    fi

    LOGGING=$(aws s3api get-bucket-logging \
        --bucket "$BUCKET" \
        --query 'LoggingEnabled.TargetBucket' \
        --output text 2>/dev/null)

    if [[ -n "$LOGGING" && "$LOGGING" != "None" ]]
    then
        write_result "$REGION" S3 ACCESS_LOGGING "$BUCKET" PASS LOW \
        "Access logging enabled"
    else
        write_result "$REGION" S3 ACCESS_LOGGING "$BUCKET" FAIL LOW \
        "Access logging disabled"
    fi

    POLICY=$(aws s3api get-bucket-policy \
        --bucket "$BUCKET" \
        --query 'Policy' \
        --output text 2>/dev/null)

    if [[ -n "$POLICY" ]]
    then
        write_result "$REGION" S3 BUCKET_POLICY "$BUCKET" PASS MEDIUM \
        "Bucket policy configured"
    else
        write_result "$REGION" S3 BUCKET_POLICY "$BUCKET" FAIL MEDIUM \
        "Bucket policy not configured"
    fi

    MFA_DELETE=$(aws s3api get-bucket-versioning \
        --bucket "$BUCKET" \
        --query 'MFADelete' \
        --output text 2>/dev/null)

    if [[ "$MFA_DELETE" == "Enabled" ]]
    then
        write_result "$REGION" S3 MFA_DELETE "$BUCKET" PASS HIGH \
        "MFA Delete enabled"
    else
        write_result "$REGION" S3 MFA_DELETE "$BUCKET" FAIL HIGH \
        "MFA Delete not enabled"
    fi

    OBJECT_LOCK=$(aws s3api get-object-lock-configuration \
        --bucket "$BUCKET" \
        --query 'ObjectLockConfiguration.ObjectLockEnabled' \
        --output text 2>/dev/null)

    if [[ "$OBJECT_LOCK" == "Enabled" ]]
    then
        write_result "$REGION" S3 OBJECT_LOCK "$BUCKET" PASS LOW \
        "Object Lock enabled"
    else
        write_result "$REGION" S3 OBJECT_LOCK "$BUCKET" FAIL LOW \
        "Object Lock not enabled"
    fi

    HTTPS_POLICY=$(aws s3api get-bucket-policy \
        --bucket "$BUCKET" \
        --query 'Policy' \
        --output text 2>/dev/null)

    if echo "$HTTPS_POLICY" | grep -q "aws:SecureTransport"
    then
        write_result "$REGION" S3 HTTPS_ONLY_POLICY "$BUCKET" PASS HIGH \
        "HTTPS-only policy configured"
    else
        write_result "$REGION" S3 HTTPS_ONLY_POLICY "$BUCKET" FAIL HIGH \
        "HTTPS-only policy not configured"
    fi

    if aws s3api get-bucket-lifecycle-configuration \
        --bucket "$BUCKET" >/dev/null 2>&1
    then
        write_result "$REGION" S3 LIFECYCLE_POLICY "$BUCKET" PASS LOW \
        "Lifecycle policy configured"
    else
        write_result "$REGION" S3 LIFECYCLE_POLICY "$BUCKET" FAIL LOW \
        "Lifecycle policy not configured"
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
    S3 \
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
echo "S3 Audit Complete"
