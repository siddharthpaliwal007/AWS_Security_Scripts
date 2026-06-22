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

SERVICE="EC2"

create_report_dir

REPORT_FILE="reports/ec2-report.csv"
HTML_FILE="reports/ec2-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# INSTANCE CHECKS
###############################################################################

INSTANCES=$(aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null)

for INSTANCE in $INSTANCES
do

    REGION="$DEFAULT_REGION"

    STATE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null)

    if [[ "$STATE" == "running" ]]
    then
        write_result "$REGION" EC2 EC2_RUNNING "$INSTANCE" PASS LOW \
        "Instance state: running"
    else
        write_result "$REGION" EC2 EC2_RUNNING "$INSTANCE" FAIL LOW \
        "Instance state: $STATE"
    fi

    IMDSV2=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' \
        --output text 2>/dev/null)

    if [[ "$IMDSV2" == "required" ]]
    then
        write_result "$REGION" EC2 IMDSV2 "$INSTANCE" PASS HIGH \
        "IMDSv2 enforced"
    else
        write_result "$REGION" EC2 IMDSV2 "$INSTANCE" FAIL HIGH \
        "IMDSv1 allowed"
    fi

    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null)

    if [[ -n "$PUBLIC_IP" && "$PUBLIC_IP" != "None" ]]
    then
        write_result "$REGION" EC2 PUBLIC_IP "$INSTANCE" FAIL HIGH \
        "Public IP: $PUBLIC_IP"
    else
        write_result "$REGION" EC2 PUBLIC_IP "$INSTANCE" PASS HIGH \
        "No public IP assigned"
    fi

    SECURITY_GROUPS=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
        --output text 2>/dev/null)

    if [[ -n "$SECURITY_GROUPS" ]]
    then
        write_result "$REGION" EC2 SECURITY_GROUP "$INSTANCE" PASS HIGH \
        "Security groups attached"
    else
        write_result "$REGION" EC2 SECURITY_GROUP "$INSTANCE" FAIL HIGH \
        "No security group attached"
    fi

    IAM_ROLE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
        --output text 2>/dev/null)

    if [[ -n "$IAM_ROLE" && "$IAM_ROLE" != "None" ]]
    then
        write_result "$REGION" EC2 IAM_ROLE "$INSTANCE" PASS MEDIUM \
        "IAM role attached"
    else
        write_result "$REGION" EC2 IAM_ROLE "$INSTANCE" FAIL MEDIUM \
        "No IAM role attached"
    fi

    VOLUMES=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' \
        --output text 2>/dev/null)

    EBS_STATUS="PASS"

    for VOLUME in $VOLUMES
    do
        ENCRYPTED=$(aws ec2 describe-volumes \
            --volume-ids "$VOLUME" \
            --query 'Volumes[0].Encrypted' \
            --output text 2>/dev/null)

        if [[ "$ENCRYPTED" != "True" ]]
        then
            EBS_STATUS="FAIL"
            break
        fi
    done

    if [[ "$EBS_STATUS" == "PASS" ]]
    then
        write_result "$REGION" EC2 EBS_ENCRYPTION "$INSTANCE" PASS HIGH \
        "All attached EBS volumes encrypted"
    else
        write_result "$REGION" EC2 EBS_ENCRYPTION "$INSTANCE" FAIL HIGH \
        "One or more EBS volumes not encrypted"
    fi

    TERMINATION=$(aws ec2 describe-instance-attribute \
        --instance-id "$INSTANCE" \
        --attribute disableApiTermination \
        --query 'DisableApiTermination.Value' \
        --output text 2>/dev/null)

    if [[ "$TERMINATION" == "True" ]]
    then
        write_result "$REGION" EC2 TERMINATION_PROTECTION "$INSTANCE" PASS LOW \
        "Termination protection enabled"
    else
        write_result "$REGION" EC2 TERMINATION_PROTECTION "$INSTANCE" FAIL LOW \
        "Termination protection disabled"
    fi

    MONITORING=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].Monitoring.State' \
        --output text 2>/dev/null)

    if [[ "$MONITORING" == "enabled" ]]
    then
        write_result "$REGION" EC2 DETAILED_MONITORING "$INSTANCE" PASS LOW \
        "Detailed monitoring enabled"
    else
        write_result "$REGION" EC2 DETAILED_MONITORING "$INSTANCE" FAIL LOW \
        "Detailed monitoring disabled"
    fi

    SOURCE_DEST=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].SourceDestCheck' \
        --output text 2>/dev/null)

    if [[ "$SOURCE_DEST" == "True" ]]
    then
        write_result "$REGION" EC2 SOURCE_DEST_CHECK "$INSTANCE" PASS LOW \
        "Source/Destination check enabled"
    else
        write_result "$REGION" EC2 SOURCE_DEST_CHECK "$INSTANCE" FAIL LOW \
        "Source/Destination check disabled"
    fi

    INSTANCE_TYPE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE" \
        --query 'Reservations[0].Instances[0].InstanceType' \
        --output text 2>/dev/null)

    write_result "$REGION" EC2 INSTANCE_TYPE "$INSTANCE" PASS LOW \
    "Instance type: $INSTANCE_TYPE"

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
    EC2 \
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
echo "EC2 Audit Complete"
