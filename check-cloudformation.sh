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

SERVICE="CLOUDFORMATION"

create_report_dir

REPORT_FILE="reports/cloudformation-report.csv"
HTML_FILE="reports/cloudformation-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# STACKS
###############################################################################

STACKS=$(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE \
    --query 'StackSummaries[*].StackName' \
    --output text 2>/dev/null)

for STACK in $STACKS
do

    REGION="$DEFAULT_REGION"

###############################################################################
# TERMINATION PROTECTION
###############################################################################

    TP=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].EnableTerminationProtection' \
        --output text 2>/dev/null)

    if [[ "$TP" == "True" ]]
    then
        write_result "$REGION" CLOUDFORMATION TERMINATION_PROTECTION "$STACK" PASS HIGH \
        "Termination protection enabled"
    else
        write_result "$REGION" CLOUDFORMATION TERMINATION_PROTECTION "$STACK" FAIL HIGH \
        "Termination protection disabled"
    fi

###############################################################################
# ROLLBACK CONFIGURATION
###############################################################################

    ROLLBACK=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].RollbackConfiguration.RollbackTriggers' \
        --output text 2>/dev/null)

    if [[ -n "$ROLLBACK" && "$ROLLBACK" != "None" ]]
    then
        write_result "$REGION" CLOUDFORMATION ROLLBACK_CONFIGURATION "$STACK" PASS LOW \
        "Rollback triggers configured"
    else
        write_result "$REGION" CLOUDFORMATION ROLLBACK_CONFIGURATION "$STACK" FAIL LOW \
        "Rollback triggers missing"
    fi

###############################################################################
# STACK POLICY
###############################################################################

    POLICY=$(aws cloudformation get-stack-policy \
        --stack-name "$STACK" \
        --query 'StackPolicyBody' \
        --output text 2>/dev/null)

    if [[ -n "$POLICY" && "$POLICY" != "None" ]]
    then
        write_result "$REGION" CLOUDFORMATION STACK_POLICY "$STACK" PASS MEDIUM \
        "Stack policy exists"
    else
        write_result "$REGION" CLOUDFORMATION STACK_POLICY "$STACK" FAIL MEDIUM \
        "Stack policy not configured"
    fi

###############################################################################
# DRIFT STATUS
###############################################################################

    DRIFT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].DriftInformation.StackDriftStatus' \
        --output text 2>/dev/null)

    if [[ "$DRIFT" != "None" ]]
    then
        write_result "$REGION" CLOUDFORMATION DRIFT_DETECTION "$STACK" PASS LOW \
        "Drift status available"
    else
        write_result "$REGION" CLOUDFORMATION DRIFT_DETECTION "$STACK" FAIL LOW \
        "No drift information"
    fi

###############################################################################
# SNS NOTIFICATION
###############################################################################

    SNS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].NotificationARNs' \
        --output text 2>/dev/null)

    if [[ -n "$SNS" && "$SNS" != "None" ]]
    then
        write_result "$REGION" CLOUDFORMATION SNS_NOTIFICATION "$STACK" PASS LOW \
        "SNS notifications configured"
    else
        write_result "$REGION" CLOUDFORMATION SNS_NOTIFICATION "$STACK" FAIL LOW \
        "SNS notifications missing"
    fi

###############################################################################
# IAM CAPABILITY
###############################################################################

    CAPABILITIES=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].Capabilities' \
        --output text 2>/dev/null)

    if echo "$CAPABILITIES" | grep -q "CAPABILITY_IAM\|CAPABILITY_NAMED_IAM"
    then
        write_result "$REGION" CLOUDFORMATION IAM_CAPABILITY "$STACK" FAIL MEDIUM \
        "Stack contains IAM resources"
    else
        write_result "$REGION" CLOUDFORMATION IAM_CAPABILITY "$STACK" PASS MEDIUM \
        "No IAM capabilities"
    fi

###############################################################################
# FAILED STACK STATUS
###############################################################################

    STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null)

    if echo "$STATUS" | grep -q "FAILED"
    then
        write_result "$REGION" CLOUDFORMATION FAILED_STACK_STATUS "$STACK" FAIL HIGH \
        "Stack status is $STATUS"
    else
        write_result "$REGION" CLOUDFORMATION FAILED_STACK_STATUS "$STACK" PASS HIGH \
        "Stack status healthy"
    fi

###############################################################################
# DELETION IN PROGRESS
###############################################################################

    if [[ "$STATUS" == "DELETE_IN_PROGRESS" ]]
    then
        write_result "$REGION" CLOUDFORMATION DELETION_IN_PROGRESS "$STACK" FAIL MEDIUM \
        "Stack deletion in progress"
    else
        write_result "$REGION" CLOUDFORMATION DELETION_IN_PROGRESS "$STACK" PASS MEDIUM \
        "Stack not being deleted"
    fi

###############################################################################
# TAGS PRESENT
###############################################################################

    TAGS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].Tags' \
        --output text 2>/dev/null)

    if [[ -n "$TAGS" && "$TAGS" != "None" ]]
    then
        write_result "$REGION" CLOUDFORMATION TAGS_PRESENT "$STACK" PASS LOW \
        "Tags configured"
    else
        write_result "$REGION" CLOUDFORMATION TAGS_PRESENT "$STACK" FAIL LOW \
        "Tags not configured"
    fi

###############################################################################
# NESTED STACK
###############################################################################

    PARENT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" \
        --query 'Stacks[0].ParentId' \
        --output text 2>/dev/null)

    if [[ -n "$PARENT" && "$PARENT" != "None" ]]
    then
        write_result "$REGION" CLOUDFORMATION NESTED_STACK "$STACK" PASS LOW \
        "Nested stack"
    else
        write_result "$REGION" CLOUDFORMATION NESTED_STACK "$STACK" PASS LOW \
        "Standalone stack"
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
    CLOUDFORMATION \
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
echo "CloudFormation Audit Complete"
