#!/bin/bash
############################################################
#
# AWS Security Audit Framework
# Master Orchestration Script
#
# Script Name : run-all.sh
#
# Purpose:
# Execute complete AWS security assessment framework
# using all available modular service audit scripts.
#
# Execution:
# ./run-all.sh
#
# Safety:
# - Read Only
# - No AWS Resource Modification
# - AWS CLI Based
# - Production Safe
#
############################################################
############################################################
# Framework Information
############################################################

FRAMEWORK_NAME="AWS Security Audit Framework"

VERSION="1.0"

START_TIME=$(date +%s)

EXECUTION_TIME=$(date)

BASE_DIR=$(pwd)

############################################################
# Banner
############################################################

echo ""
echo "============================================================"
echo "        AWS SECURITY AUDIT FRAMEWORK"
echo "============================================================"
echo ""
echo "Version        : $VERSION"
echo "Execution Time : $EXECUTION_TIME"
echo "Working Dir    : $BASE_DIR"
echo ""
echo "============================================================"
echo ""

############################################################
# Validate Framework Directory
############################################################

echo "[INFO] Validating framework directory..."

if [[ ! -f "./bootstrap.sh" ]]
then

    echo "[ERROR] bootstrap.sh not found"
    echo "[ERROR] Please execute run-all.sh from framework root directory"

    exit 1

fi

if [[ ! -f "./common.sh" ]]
then

    echo "[ERROR] common.sh not found"
    echo "[ERROR] Framework dependency missing"

    exit 1

fi

echo "[PASS] Framework files detected"

############################################################
# Create Required Directories
############################################################

echo "[INFO] Preparing directories..."

if [[ ! -d "reports" ]]
then

    mkdir reports

fi

if [[ ! -d "logs" ]]
then

    mkdir logs

fi

echo "[PASS] Directory validation completed"

############################################################
# Initialize Master Files
############################################################

MASTER_LOG="logs/run-all.log"

EXECUTION_REPORT="reports/execution-summary.csv"

MASTER_REPORT="reports/master-security-dashboard.html"

echo "============================================================" \
> "$MASTER_LOG"

echo "AWS Security Audit Framework Execution Log" \
>> "$MASTER_LOG"

echo "Started : $EXECUTION_TIME" \
>> "$MASTER_LOG"

echo "============================================================" \
>> "$MASTER_LOG"

echo "Timestamp,Service,Script,Status,Duration,Details" \
> "$EXECUTION_REPORT"

############################################################
# Load Common Functions
############################################################

echo "[INFO] Loading common functions..."

source ./common.sh

if [[ $? -ne 0 ]]
then

    echo "[ERROR] Unable to load common.sh"

    exit 1

fi

echo "[PASS] common.sh loaded"

############################################################
# Load Configuration
############################################################

if [[ -f "./config.conf" ]]
then

    echo "[INFO] Loading existing configuration..."

    source ./config.conf

    echo "[PASS] Configuration loaded"

else

    echo "[WARN] config.conf not found"
    echo "[INFO] Bootstrap execution required"

fi

############################################################
# Part 1 Completed
############################################################

echo ""
echo "[PASS] Framework initialization completed"
echo ""

############################################################
# Bootstrap Validation
############################################################

echo "[INFO] Checking framework configuration..."

if [[ ! -f "./config.conf" ]]
then

    echo "[INFO] Running bootstrap.sh..."

    echo "$(date) : Starting bootstrap execution" \
    >> "$MASTER_LOG"

    bash ./bootstrap.sh >> "$MASTER_LOG" 2>&1

    if [[ $? -ne 0 ]]
    then

        echo "[ERROR] Bootstrap execution failed"

        echo "$(date) : Bootstrap failed" \
        >> "$MASTER_LOG"

        exit 1

    fi

    echo "[PASS] Bootstrap completed successfully"

    source ./config.conf

else

    echo "[PASS] Existing configuration available"

fi

############################################################
# AWS CLI Validation
############################################################

echo "[INFO] Validating AWS CLI..."

AWS_VERSION=$(aws --version 2>/dev/null)

if [[ -z "$AWS_VERSION" ]]
then

    echo "[ERROR] AWS CLI not installed"

    echo "$(date) : AWS CLI validation failed" \
    >> "$MASTER_LOG"

    exit 1

fi

echo "[PASS] AWS CLI detected"

############################################################
# AWS Authentication Validation
############################################################

echo "[INFO] Validating AWS authentication..."

ACCOUNT_ID=$(aws sts get-caller-identity \
--query Account \
--output text \
2>/dev/null)

if [[ -z "$ACCOUNT_ID" ]]
then

    echo "[ERROR] AWS authentication failed"

    echo "$(date) : AWS authentication failed" \
    >> "$MASTER_LOG"

    exit 1

fi

echo "[PASS] AWS authentication successful"

echo "Account ID : $ACCOUNT_ID"

############################################################
# Region Detection
############################################################

CURRENT_REGION=$(aws configure get region 2>/dev/null)

if [[ -z "$CURRENT_REGION" ]]
then

    CURRENT_REGION="Not Configured"

fi

echo "Region     : $CURRENT_REGION"

echo ""
echo "============================================================"
echo " Account Information"
echo "============================================================"
echo ""
echo "Account : $ACCOUNT_ID"
echo "Region  : $CURRENT_REGION"
echo ""

############################################################
# Service Audit Registry
############################################################

SERVICES=(

"IAM:check-iam.sh"

"CloudTrail:check-cloudtrail.sh"

"S3:check-s3.sh"

"EC2:check-ec2.sh"

"SecurityGroup:check-security-groups.sh"

"VPC:check-vpc.sh"

"RDS:check-rds.sh"

"Lambda:check-lambda.sh"

"EBS:check-ebs.sh"

"CloudFormation:check-cloudformation.sh"

"CloudWatch:check-cloudwatch.sh"

"Config:check-config.sh"

"KMS:check-kms.sh"

"SNS:check-sns.sh"

"SQS:check-sqs.sh"

"SecretsManager:check-secretsmanager.sh"

"ECR:check-ecr.sh"

"ECS:check-ecs.sh"

"EKS:check-eks.sh"

"GuardDuty:check-guardduty.sh"

"SecurityHub:check-securityhub.sh"

"Macie:check-macie.sh"

"Route53:check-route53.sh"

"ELB:check-elb.sh"

"ACM:check-acm.sh"

"Redshift:check-redshift.sh"

"DynamoDB:check-dynamodb.sh"

"ElastiCache:check-elasticache.sh"

"Organizations:check-organizations.sh"

"AccessAnalyzer:check-access-analyzer.sh"

"Inspector:check-inspector.sh"

"WAF:check-waf.sh"

"Backup:check-backup.sh"

)

############################################################
# Initialize Execution Counters
############################################################

TOTAL_SERVICES=${#SERVICES[@]}

CURRENT_SERVICE=1

SUCCESS_COUNT=0

FAILED_COUNT=0

SKIPPED_COUNT=0

echo "Total Services Registered : $TOTAL_SERVICES"

echo ""

echo "============================================================" \
>> "$MASTER_LOG"

echo "Services Registered : $TOTAL_SERVICES" \
>> "$MASTER_LOG"

echo "============================================================" \
>> "$MASTER_LOG"

############################################################
# Part 2 Completed
############################################################

echo "[PASS] Framework validation completed"

echo "[PASS] Service registry initialized"

echo ""

############################################################
# Service Execution Engine
############################################################

echo ""
echo "============================================================"
echo " Starting AWS Security Assessment"
echo "============================================================"
echo ""

echo "$(date) : Security assessment execution started" \
>> "$MASTER_LOG"

for ITEM in "${SERVICES[@]}"
do

    ########################################################
    # Extract Service Name And Script Name
    ########################################################

    SERVICE_NAME=$(echo "$ITEM" | cut -d':' -f1)

    SCRIPT_NAME=$(echo "$ITEM" | cut -d':' -f2)

    echo ""
    echo "------------------------------------------------------------"
    echo "[$CURRENT_SERVICE/$TOTAL_SERVICES] Running $SERVICE_NAME"
    echo "Script : $SCRIPT_NAME"
    echo "------------------------------------------------------------"

    echo "$(date) : Starting $SERVICE_NAME scan" \
    >> "$MASTER_LOG"

    SERVICE_START=$(date +%s)

    ########################################################
    # Validate Script Exists
    ########################################################

    if [[ ! -f "$SCRIPT_NAME" ]]
    then

        echo "[SKIPPED] $SCRIPT_NAME not found"

        SERVICE_END=$(date +%s)

        DURATION=$((SERVICE_END-SERVICE_START))

        echo "$(date),$SERVICE_NAME,$SCRIPT_NAME,SKIPPED,${DURATION}s,Script file missing" \
        >> "$EXECUTION_REPORT"

        echo "$(date) : $SCRIPT_NAME missing" \
        >> "$MASTER_LOG"

        SKIPPED_COUNT=$((SKIPPED_COUNT+1))

        CURRENT_SERVICE=$((CURRENT_SERVICE+1))

        continue

    fi

    ########################################################
    # Execute Service Audit Script
    ########################################################

    bash "$SCRIPT_NAME" >> "$MASTER_LOG" 2>&1

    RESULT=$?

    SERVICE_END=$(date +%s)

    DURATION=$((SERVICE_END-SERVICE_START))

    ########################################################
    # Capture Execution Result
    ########################################################

    if [[ $RESULT -eq 0 ]]
    then

        echo "[PASS] $SERVICE_NAME completed"

        echo "$(date),$SERVICE_NAME,$SCRIPT_NAME,PASS,${DURATION}s,Completed successfully" \
        >> "$EXECUTION_REPORT"

        echo "$(date) : $SERVICE_NAME completed successfully" \
        >> "$MASTER_LOG"

        SUCCESS_COUNT=$((SUCCESS_COUNT+1))

    else

        echo "[FAILED] $SERVICE_NAME encountered error"

        echo "$(date),$SERVICE_NAME,$SCRIPT_NAME,FAILED,${DURATION}s,Check execution logs" \
        >> "$EXECUTION_REPORT"

        echo "$(date) : $SERVICE_NAME failed" \
        >> "$MASTER_LOG"

        FAILED_COUNT=$((FAILED_COUNT+1))

    fi

    ########################################################
    # Progress Increment
    ########################################################

    CURRENT_SERVICE=$((CURRENT_SERVICE+1))

done

############################################################
# Execution Statistics
############################################################

echo ""
echo "============================================================"
echo " Service Execution Completed"
echo "============================================================"

echo ""

echo "Total Services : $TOTAL_SERVICES"

echo "Successful     : $SUCCESS_COUNT"

echo "Failed         : $FAILED_COUNT"

echo "Skipped        : $SKIPPED_COUNT"

echo ""

echo "============================================================" \
>> "$MASTER_LOG"

echo "Execution Statistics" \
>> "$MASTER_LOG"

echo "Successful : $SUCCESS_COUNT" \
>> "$MASTER_LOG"

echo "Failed     : $FAILED_COUNT" \
>> "$MASTER_LOG"

echo "Skipped    : $SKIPPED_COUNT" \
>> "$MASTER_LOG"

echo "============================================================" \
>> "$MASTER_LOG"

############################################################
# Part 3 Completed
############################################################

echo "[PASS] Service execution engine completed"

echo ""

############################################################
# Report Normalization Engine
############################################################

echo ""
echo "============================================================"
echo " Validating Generated Reports"
echo "============================================================"
echo ""

echo "$(date) : Starting report normalization" \
>> "$MASTER_LOG"

for CSV_FILE in reports/*.csv
do

    ########################################################
    # Ignore Execution Summary
    ########################################################

    if [[ "$CSV_FILE" == "$EXECUTION_REPORT" ]]
    then

        continue

    fi

    ########################################################
    # Validate Empty Reports
    ########################################################

    LINE_COUNT=$(wc -l < "$CSV_FILE")

    if [[ $LINE_COUNT -le 1 ]]
    then

        SERVICE_NAME=$(basename "$CSV_FILE" | cut -d'-' -f1)

        echo "[INFO] Empty report detected : $SERVICE_NAME"

        echo "$(date),$ACCOUNT_ID,$CURRENT_REGION,$SERVICE_NAME,SERVICE_RESOURCE_CHECK,Account,PASS,LOW,No resources found or service not configured in this AWS account" \
        >> "$CSV_FILE"

        echo "$(date) : Default record inserted for $SERVICE_NAME" \
        >> "$MASTER_LOG"

    ########################################################
    # Regenerate HTML After Adding Default Record
    ########################################################

        HTML_FILE=$(echo "$CSV_FILE" | sed 's/\.csv$/.html/')
        generate_html "$CSV_FILE" "$HTML_FILE"

    fi

done

############################################################
# Master Statistics Calculation
############################################################

echo "[INFO] Calculating security statistics..."

TOTAL_CHECKS=0

TOTAL_PASS=0

TOTAL_FAIL=0

TOTAL_CRITICAL=0

TOTAL_HIGH=0

TOTAL_MEDIUM=0

TOTAL_LOW=0

for CSV_FILE in reports/*.csv
do

    if [[ "$CSV_FILE" == "$EXECUTION_REPORT" ]]
    then

        continue

    fi

    CHECK_COUNT=$(tail -n +2 "$CSV_FILE" | wc -l)

    PASS_COUNT=$(grep ",PASS," "$CSV_FILE" | wc -l)

    FAIL_COUNT=$(grep ",FAIL," "$CSV_FILE" | wc -l)

    CRITICAL_COUNT=$(grep ",CRITICAL," "$CSV_FILE" | wc -l)

    HIGH_COUNT=$(grep ",HIGH," "$CSV_FILE" | wc -l)

    MEDIUM_COUNT=$(grep ",MEDIUM," "$CSV_FILE" | wc -l)

    LOW_COUNT=$(grep ",LOW," "$CSV_FILE" | wc -l)

    TOTAL_CHECKS=$((TOTAL_CHECKS+CHECK_COUNT))

    TOTAL_PASS=$((TOTAL_PASS+PASS_COUNT))

    TOTAL_FAIL=$((TOTAL_FAIL+FAIL_COUNT))

    TOTAL_CRITICAL=$((TOTAL_CRITICAL+CRITICAL_COUNT))

    TOTAL_HIGH=$((TOTAL_HIGH+HIGH_COUNT))

    TOTAL_MEDIUM=$((TOTAL_MEDIUM+MEDIUM_COUNT))

    TOTAL_LOW=$((TOTAL_LOW+LOW_COUNT))

done

############################################################
# Generate Master HTML Dashboard
############################################################

echo "[INFO] Generating master dashboard..."

cat > "$MASTER_REPORT" <<EOF

<!DOCTYPE html>

<html>

<head>

<title>AWS Security Audit Dashboard</title>

<style>

body
{

background:#111827;

color:white;

font-family:Arial;

padding:30px;

}

.card
{

background:#1f2937;

padding:20px;

margin:10px;

display:inline-block;

border-radius:10px;

width:180px;

text-align:center;

}

table
{

width:100%;

border-collapse:collapse;

margin-top:30px;

}

th,td
{

border:1px solid #374151;

padding:10px;

}

th
{

background:#374151;

}

</style>

</head>

<body>

<h1>AWS Security Audit Summary</h1>

<p>

Account ID : $ACCOUNT_ID

<br>

Region : $CURRENT_REGION

<br>

Generated : $(date)

</p>

<div class="card">

<h2>$TOTAL_CHECKS</h2>

<p>Total Checks</p>

</div>

<div class="card">

<h2>$TOTAL_PASS</h2>

<p>Passed</p>

</div>

<div class="card">

<h2>$TOTAL_FAIL</h2>

<p>Failed</p>

</div>

<div class="card">

<h2>$TOTAL_CRITICAL</h2>

<p>Critical</p>

</div>

<div class="card">

<h2>$TOTAL_HIGH</h2>

<p>High</p>

</div>

<div class="card">

<h2>$TOTAL_MEDIUM</h2>

<p>Medium</p>

</div>

<div class="card">

<h2>$TOTAL_LOW</h2>

<p>Low</p>

</div>

<h2>Service Execution Status</h2>

<table>

<tr>

<th>Service</th>

<th>Script</th>

<th>Status</th>

<th>Duration</th>

<th>Details</th>

</tr>

EOF

############################################################
# Add Execution Details To HTML
############################################################

tail -n +2 "$EXECUTION_REPORT" | while IFS=',' read TIME SERVICE SCRIPT STATUS DURATION DETAILS

do

cat >> "$MASTER_REPORT" <<EOF

<tr>

<td>$SERVICE</td>

<td>$SCRIPT</td>

<td>$STATUS</td>

<td>$DURATION</td>

<td>$DETAILS</td>

</tr>

EOF

done

cat >> "$MASTER_REPORT" <<EOF

</table>

</body>

</html>

EOF

############################################################
# Part 4 Completed
############################################################

echo "[PASS] Report normalization completed"

echo "[PASS] Master dashboard generated"

echo ""

echo "Dashboard:"
echo "$MASTER_REPORT"

echo ""

############################################################
# Optional Report Upload
############################################################

echo ""
echo "============================================================"
echo " Report Upload Processing"
echo "============================================================"
echo ""

echo "$(date) : Checking report upload configuration" \
>> "$MASTER_LOG"

if [[ "$AUTO_UPLOAD" == "true" ]]
then

    echo "[INFO] AUTO_UPLOAD enabled"

    echo "[INFO] Uploading reports to S3..."


############################################################
# Upload Master Reports Only
############################################################

    UPLOAD_STATUS=0

    ############################################################
    # Upload Master Dashboard
    ############################################################

    if [[ -f "$MASTER_REPORT" ]]
    then

        aws s3 cp \
        "$MASTER_REPORT" \
        "s3://$REPORT_BUCKET/$ACCOUNT_ID/$DATE_FOLDER/master-security-dashboard.html" \
        >/dev/null

        if [[ $? -ne 0 ]]
        then

            UPLOAD_STATUS=1

        fi

    fi

    ############################################################
    # Upload Execution Summary
    ############################################################

    if [[ -f "$EXECUTION_REPORT" ]]
    then

        aws s3 cp \
        "$EXECUTION_REPORT" \
        "s3://$REPORT_BUCKET/$ACCOUNT_ID/$DATE_FOLDER/execution-summary.csv" \
        >/dev/null

        if [[ $? -ne 0 ]]
        then

            UPLOAD_STATUS=1

        fi

    fi

    ############################################################
    # Check Upload Result
    ############################################################

    if [[ $UPLOAD_STATUS -eq 0 ]]
    then

        echo "[PASS] Master reports uploaded successfully"

        echo "$(date) : Master reports uploaded successfully" \
        >> "$MASTER_LOG"

    else

        echo "[WARN] Master report upload failed"

        echo "$(date) : Master report upload failed" \
        >> "$MASTER_LOG"

    fi

else

    echo "[INFO] AUTO_UPLOAD disabled"

    echo "[INFO] Reports stored locally"

    echo "$(date) : S3 upload skipped" \
    >> "$MASTER_LOG"

fi

############################################################
# Calculate Total Runtime
############################################################

END_TIME=$(date +%s)

TOTAL_RUNTIME=$((END_TIME-START_TIME))

MINUTES=$((TOTAL_RUNTIME/60))

SECONDS=$((TOTAL_RUNTIME%60))

############################################################
# Final Execution Log
############################################################

echo "" \
>> "$MASTER_LOG"

echo "============================================================" \
>> "$MASTER_LOG"

echo "Execution Completed" \
>> "$MASTER_LOG"

echo "Completed Time : $(date)" \
>> "$MASTER_LOG"

echo "Runtime : ${MINUTES} minutes ${SECONDS} seconds" \
>> "$MASTER_LOG"

echo "============================================================" \
>> "$MASTER_LOG"

############################################################
# Final Console Summary
############################################################

echo ""
echo "============================================================"
echo " AWS SECURITY AUDIT COMPLETED"
echo "============================================================"

echo ""

echo "Account ID : $ACCOUNT_ID"

echo "Region     : $CURRENT_REGION"

echo ""

echo "Services Scanned : $TOTAL_SERVICES"

echo "Successful       : $SUCCESS_COUNT"

echo "Failed           : $FAILED_COUNT"

echo "Skipped          : $SKIPPED_COUNT"

echo ""

echo "------------------------------------------------------------"

echo "Security Findings Summary"

echo "------------------------------------------------------------"

echo ""

echo "Total Checks : $TOTAL_CHECKS"

echo ""

echo "PASS     : $TOTAL_PASS"

echo "FAIL     : $TOTAL_FAIL"

echo ""

echo "CRITICAL : $TOTAL_CRITICAL"

echo "HIGH     : $TOTAL_HIGH"

echo "MEDIUM   : $TOTAL_MEDIUM"

echo "LOW      : $TOTAL_LOW"

echo ""

echo "------------------------------------------------------------"

echo "Generated Reports"

echo "------------------------------------------------------------"

echo ""

echo "Individual Reports :"

echo "reports/*.html"

echo ""

echo "Master Dashboard :"

echo "$MASTER_REPORT"

echo ""

echo "Execution Summary :"

echo "$EXECUTION_REPORT"


echo ""

echo "Execution Logs :"

echo "$MASTER_LOG"

echo ""

echo "Runtime : ${MINUTES} minutes ${SECONDS} seconds"

echo ""

echo "============================================================"

echo " Framework Execution Finished Successfully"

echo "============================================================"

echo ""

############################################################
# Exit Handling
############################################################

if [[ $FAILED_COUNT -gt 0 ]]
then

    echo "[WARN] Some service checks encountered execution issues"

    echo "[INFO] Review logs for details"

    exit 1

else
    echo "[PASS] All available checks completed"

    exit 0

fi
