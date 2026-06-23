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

SERVICE="RDS"

create_report_dir

REPORT_FILE="reports/rds-report.csv"
HTML_FILE="reports/rds-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# RDS CHECKS
###############################################################################

DBS=$(aws rds describe-db-instances \
    --query 'DBInstances[*].DBInstanceIdentifier' \
    --output text 2>/dev/null)

for DB in $DBS
do

    REGION="$DEFAULT_REGION"

###############################################################################
# STORAGE ENCRYPTION
###############################################################################

    ENCRYPTED=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].StorageEncrypted' \
        --output text 2>/dev/null)

    if [[ "$ENCRYPTED" == "True" ]]
    then
        write_result "$REGION" RDS STORAGE_ENCRYPTION "$DB" PASS HIGH \
        "Storage encryption enabled"
    else
        write_result "$REGION" RDS STORAGE_ENCRYPTION "$DB" FAIL HIGH \
        "Storage encryption disabled"
    fi

###############################################################################
# PUBLIC ACCESSIBILITY
###############################################################################

    PUBLIC=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].PubliclyAccessible' \
        --output text 2>/dev/null)

    if [[ "$PUBLIC" == "True" ]]
    then
        write_result "$REGION" RDS PUBLIC_ACCESS "$DB" FAIL CRITICAL \
        "Database publicly accessible"
    else
        write_result "$REGION" RDS PUBLIC_ACCESS "$DB" PASS CRITICAL \
        "Database not publicly accessible"
    fi

###############################################################################
# BACKUP RETENTION
###############################################################################

    BACKUP_RETENTION=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].BackupRetentionPeriod' \
        --output text 2>/dev/null)

    if [[ "$BACKUP_RETENTION" -gt 0 ]]
    then
        write_result "$REGION" RDS BACKUP_RETENTION "$DB" PASS HIGH \
        "Backup retention period: $BACKUP_RETENTION days"
    else
        write_result "$REGION" RDS BACKUP_RETENTION "$DB" FAIL HIGH \
        "Automated backups disabled"
    fi

###############################################################################
# DELETION PROTECTION
###############################################################################

    DELETION_PROTECTION=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].DeletionProtection' \
        --output text 2>/dev/null)

    if [[ "$DELETION_PROTECTION" == "True" ]]
    then
        write_result "$REGION" RDS DELETION_PROTECTION "$DB" PASS MEDIUM \
        "Deletion protection enabled"
    else
        write_result "$REGION" RDS DELETION_PROTECTION "$DB" FAIL MEDIUM \
        "Deletion protection disabled"
    fi

###############################################################################
# MULTI-AZ
###############################################################################

    MULTI_AZ=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].MultiAZ' \
        --output text 2>/dev/null)

    if [[ "$MULTI_AZ" == "True" ]]
    then
        write_result "$REGION" RDS MULTI_AZ "$DB" PASS LOW \
        "Multi-AZ enabled"
    else
        write_result "$REGION" RDS MULTI_AZ "$DB" FAIL LOW \
        "Single AZ deployment"
    fi

###############################################################################
# IAM DATABASE AUTHENTICATION
###############################################################################

    IAM_AUTH=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].IAMDatabaseAuthenticationEnabled' \
        --output text 2>/dev/null)

    if [[ "$IAM_AUTH" == "True" ]]
    then
        write_result "$REGION" RDS IAM_AUTH "$DB" PASS MEDIUM \
        "IAM database authentication enabled"
    else
        write_result "$REGION" RDS IAM_AUTH "$DB" FAIL MEDIUM \
        "IAM database authentication disabled"
    fi

###############################################################################
# ENHANCED MONITORING
###############################################################################

    MONITORING_INTERVAL=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].MonitoringInterval' \
        --output text 2>/dev/null)

    if [[ "$MONITORING_INTERVAL" -gt 0 ]]
    then
        write_result "$REGION" RDS ENHANCED_MONITORING "$DB" PASS LOW \
        "Enhanced monitoring enabled"
    else
        write_result "$REGION" RDS ENHANCED_MONITORING "$DB" FAIL LOW \
        "Enhanced monitoring disabled"
    fi

###############################################################################
# PERFORMANCE INSIGHTS
###############################################################################

    PERFORMANCE_INSIGHTS=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].PerformanceInsightsEnabled' \
        --output text 2>/dev/null)

    if [[ "$PERFORMANCE_INSIGHTS" == "True" ]]
    then
        write_result "$REGION" RDS PERFORMANCE_INSIGHTS "$DB" PASS LOW \
        "Performance Insights enabled"
    else
        write_result "$REGION" RDS PERFORMANCE_INSIGHTS "$DB" FAIL LOW \
        "Performance Insights disabled"
    fi

###############################################################################
# COPY TAGS TO SNAPSHOT
###############################################################################

    COPY_TAGS=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].CopyTagsToSnapshot' \
        --output text 2>/dev/null)

    if [[ "$COPY_TAGS" == "True" ]]
    then
        write_result "$REGION" RDS COPY_TAGS_TO_SNAPSHOT "$DB" PASS LOW \
        "Tags copied to snapshots"
    else
        write_result "$REGION" RDS COPY_TAGS_TO_SNAPSHOT "$DB" FAIL LOW \
        "Tags not copied to snapshots"
    fi

###############################################################################
# AUTO MINOR VERSION UPGRADE
###############################################################################

    AUTO_MINOR=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB" \
        --query 'DBInstances[0].AutoMinorVersionUpgrade' \
        --output text 2>/dev/null)

    if [[ "$AUTO_MINOR" == "True" ]]
    then
        write_result "$REGION" RDS AUTO_MINOR_UPGRADE "$DB" PASS LOW \
        "Automatic minor upgrades enabled"
    else
        write_result "$REGION" RDS AUTO_MINOR_UPGRADE "$DB" FAIL LOW \
        "Automatic minor upgrades disabled"
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
    RDS \
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
echo "RDS Audit Complete"
