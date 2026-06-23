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

SERVICE="EBS"

create_report_dir

REPORT_FILE="reports/ebs-report.csv"
HTML_FILE="reports/ebs-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# EBS VOLUME CHECKS
###############################################################################

VOLUMES=$(aws ec2 describe-volumes \
    --query 'Volumes[*].VolumeId' \
    --output text 2>/dev/null)

for VOLUME in $VOLUMES
do

    REGION="$DEFAULT_REGION"

###############################################################################
# EBS ENCRYPTION
###############################################################################

    ENCRYPTED=$(aws ec2 describe-volumes \
        --volume-ids "$VOLUME" \
        --query 'Volumes[0].Encrypted' \
        --output text 2>/dev/null)

    if [[ "$ENCRYPTED" == "True" ]]
    then
        write_result "$REGION" EBS EBS_ENCRYPTION "$VOLUME" PASS HIGH \
        "Volume encrypted"
    else
        write_result "$REGION" EBS EBS_ENCRYPTION "$VOLUME" FAIL HIGH \
        "Volume not encrypted"
    fi

###############################################################################
# VOLUME ATTACHMENT
###############################################################################

    ATTACHED=$(aws ec2 describe-volumes \
        --volume-ids "$VOLUME" \
        --query 'Volumes[0].Attachments[0].InstanceId' \
        --output text 2>/dev/null)

    if [[ -n "$ATTACHED" && "$ATTACHED" != "None" ]]
    then
        write_result "$REGION" EBS EBS_IN_USE "$VOLUME" PASS LOW \
        "Volume attached to instance"
    else
        write_result "$REGION" EBS EBS_IN_USE "$VOLUME" FAIL LOW \
        "Unused volume"
    fi

###############################################################################
# DELETE ON TERMINATION
###############################################################################

    DELETE_ON_TERMINATION=$(aws ec2 describe-volumes \
        --volume-ids "$VOLUME" \
        --query 'Volumes[0].Attachments[0].DeleteOnTermination' \
        --output text 2>/dev/null)

    if [[ "$DELETE_ON_TERMINATION" == "True" ]]
    then
        write_result "$REGION" EBS DELETE_ON_TERMINATION "$VOLUME" PASS LOW \
        "Delete on termination enabled"
    else
        write_result "$REGION" EBS DELETE_ON_TERMINATION "$VOLUME" FAIL LOW \
        "Delete on termination disabled"
    fi

###############################################################################
# FAST SNAPSHOT RESTORE
###############################################################################

    FSR=$(aws ec2 describe-fast-snapshot-restores \
        --filters Name=snapshot-id,Values=* \
        --query 'FastSnapshotRestores[*].State' \
        --output text 2>/dev/null)

    if echo "$FSR" | grep -q "enabled"
    then
        write_result "$REGION" EBS FAST_SNAPSHOT_RESTORE "$VOLUME" PASS LOW \
        "Fast snapshot restore enabled"
    else
        write_result "$REGION" EBS FAST_SNAPSHOT_RESTORE "$VOLUME" FAIL LOW \
        "Fast snapshot restore disabled"
    fi

###############################################################################
# PROVISIONED IOPS
###############################################################################

    IOPS=$(aws ec2 describe-volumes \
        --volume-ids "$VOLUME" \
        --query 'Volumes[0].Iops' \
        --output text 2>/dev/null)

    if [[ "$IOPS" -gt 0 ]]
    then
        write_result "$REGION" EBS EBS_IOPS "$VOLUME" PASS LOW \
        "Provisioned IOPS: $IOPS"
    else
        write_result "$REGION" EBS EBS_IOPS "$VOLUME" FAIL LOW \
        "No provisioned IOPS"
    fi
done
###############################################################################
# SNAPSHOT CHECKS
###############################################################################

SNAPSHOTS=$(aws ec2 describe-snapshots \
    --owner-ids self \
    --query 'Snapshots[*].SnapshotId' \
    --output text 2>/dev/null)

for SNAPSHOT in $SNAPSHOTS
do

###############################################################################
# PUBLIC SNAPSHOT
###############################################################################

    PUBLIC=$(aws ec2 describe-snapshot-attribute \
        --snapshot-id "$SNAPSHOT" \
        --attribute createVolumePermission \
        --query 'CreateVolumePermissions[?Group==`all`].Group' \
        --output text 2>/dev/null)

    if [[ "$PUBLIC" == "all" ]]
    then
        write_result "$REGION" EBS PUBLIC_SNAPSHOT "$SNAPSHOT" FAIL CRITICAL \
        "Snapshot shared publicly"
    else
        write_result "$REGION" EBS PUBLIC_SNAPSHOT "$SNAPSHOT" PASS CRITICAL \
        "Snapshot not public"
    fi

###############################################################################
# SNAPSHOT ENCRYPTION
###############################################################################

    ENCRYPTED=$(aws ec2 describe-snapshots \
        --snapshot-ids "$SNAPSHOT" \
        --query 'Snapshots[0].Encrypted' \
        --output text 2>/dev/null)

    if [[ "$ENCRYPTED" == "True" ]]
    then
        write_result "$REGION" EBS SNAPSHOT_ENCRYPTION "$SNAPSHOT" PASS HIGH \
        "Snapshot encrypted"
    else
        write_result "$REGION" EBS SNAPSHOT_ENCRYPTION "$SNAPSHOT" FAIL HIGH \
        "Snapshot not encrypted"
    fi

###############################################################################
# SNAPSHOT STATE
###############################################################################

    STATE=$(aws ec2 describe-snapshots \
        --snapshot-ids "$SNAPSHOT" \
        --query 'Snapshots[0].State' \
        --output text 2>/dev/null)

    if [[ "$STATE" == "completed" ]]
    then
        write_result "$REGION" EBS SNAPSHOT_COMPLETED "$SNAPSHOT" PASS LOW \
        "Snapshot completed"
    else
        write_result "$REGION" EBS SNAPSHOT_COMPLETED "$SNAPSHOT" FAIL LOW \
        "Snapshot state: $STATE"
    fi

###############################################################################
# SNAPSHOT DESCRIPTION
###############################################################################

    DESCRIPTION=$(aws ec2 describe-snapshots \
        --snapshot-ids "$SNAPSHOT" \
        --query 'Snapshots[0].Description' \
        --output text 2>/dev/null)

    if [[ -n "$DESCRIPTION" && "$DESCRIPTION" != "None" ]]
    then
        write_result "$REGION" EBS SNAPSHOT_DESCRIPTION "$SNAPSHOT" PASS LOW \
        "Description present"
    else
        write_result "$REGION" EBS SNAPSHOT_DESCRIPTION "$SNAPSHOT" FAIL LOW \
        "No description"
    fi

###############################################################################
# SNAPSHOT TAGS
###############################################################################

    TAGS=$(aws ec2 describe-snapshots \
        --snapshot-ids "$SNAPSHOT" \
        --query 'Snapshots[0].Tags' \
        --output text 2>/dev/null)

    if [[ -n "$TAGS" && "$TAGS" != "None" ]]
    then
        write_result "$REGION" EBS SNAPSHOT_TAGS "$SNAPSHOT" PASS LOW \
        "Tags configured"
    else
        write_result "$REGION" EBS SNAPSHOT_TAGS "$SNAPSHOT" FAIL LOW \
        "No tags configured"
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
    EBS \
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
echo "EBS Audit Complete"
