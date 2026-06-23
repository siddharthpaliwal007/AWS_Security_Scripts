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

SERVICE="CLOUDWATCH"

create_report_dir

REPORT_FILE="reports/cloudwatch-report.csv"
HTML_FILE="reports/cloudwatch-report.html"

init_csv "$REPORT_FILE"

REGION="$DEFAULT_REGION"

###############################################################################
# CLOUDWATCH ALARMS
###############################################################################

ALARMS=$(aws cloudwatch describe-alarms \
    --query 'MetricAlarms[*].AlarmName' \
    --output text 2>/dev/null)

if [[ -n "$ALARMS" ]]
then
    write_result "$REGION" CLOUDWATCH CLOUDWATCH_ALARMS Account PASS HIGH \
    "CloudWatch alarms configured"
else
    write_result "$REGION" CLOUDWATCH CLOUDWATCH_ALARMS Account FAIL HIGH \
    "No CloudWatch alarms found"
fi

###############################################################################
# ALARM ACTIONS
###############################################################################

ACTIONS=$(aws cloudwatch describe-alarms \
    --query 'MetricAlarms[?length(AlarmActions)>`0`].AlarmName' \
    --output text 2>/dev/null)

if [[ -n "$ACTIONS" ]]
then
    write_result "$REGION" CLOUDWATCH ALARM_ACTIONS Account PASS HIGH \
    "Alarm actions configured"
else
    write_result "$REGION" CLOUDWATCH ALARM_ACTIONS Account FAIL HIGH \
    "Alarm actions missing"
fi

###############################################################################
# INSUFFICIENT DATA ACTIONS
###############################################################################

INSUFFICIENT=$(aws cloudwatch describe-alarms \
    --query 'MetricAlarms[?length(InsufficientDataActions)>`0`].AlarmName' \
    --output text 2>/dev/null)

if [[ -n "$INSUFFICIENT" ]]
then
    write_result "$REGION" CLOUDWATCH INSUFFICIENT_DATA_ACTIONS Account PASS LOW \
    "Insufficient data actions configured"
else
    write_result "$REGION" CLOUDWATCH INSUFFICIENT_DATA_ACTIONS Account FAIL LOW \
    "No insufficient data actions"
fi

###############################################################################
# SNS TOPICS
###############################################################################

SNS=$(aws cloudwatch describe-alarms \
    --query 'MetricAlarms[?contains(join(``,AlarmActions),`arn:aws:sns:`)].AlarmName' \
    --output text 2>/dev/null)

if [[ -n "$SNS" ]]
then
    write_result "$REGION" CLOUDWATCH SNS_TOPIC Account PASS MEDIUM \
    "SNS notifications configured"
else
    write_result "$REGION" CLOUDWATCH SNS_TOPIC Account FAIL MEDIUM \
    "SNS notifications missing"
fi

###############################################################################
# DASHBOARDS
###############################################################################

DASHBOARDS=$(aws cloudwatch list-dashboards \
    --query 'DashboardEntries[*].DashboardName' \
    --output text 2>/dev/null)

if [[ -n "$DASHBOARDS" ]]
then
    write_result "$REGION" CLOUDWATCH DASHBOARDS Account PASS LOW \
    "CloudWatch dashboards configured"
else
    write_result "$REGION" CLOUDWATCH DASHBOARDS Account FAIL LOW \
    "No dashboards found"
fi

###############################################################################
# LOG GROUP RETENTION
###############################################################################

RETENTION=$(aws logs describe-log-groups \
    --query 'logGroups[?retentionInDays!=null].logGroupName' \
    --output text 2>/dev/null)

if [[ -n "$RETENTION" ]]
then
    write_result "$REGION" CLOUDWATCH LOG_GROUP_RETENTION Account PASS MEDIUM \
    "Log retention configured"
else
    write_result "$REGION" CLOUDWATCH LOG_GROUP_RETENTION Account FAIL MEDIUM \
    "No log retention configured"
fi

###############################################################################
# LOG GROUP ENCRYPTION
###############################################################################

ENCRYPTION=$(aws logs describe-log-groups \
    --query 'logGroups[?kmsKeyId!=null].logGroupName' \
    --output text 2>/dev/null)

if [[ -n "$ENCRYPTION" ]]
then
    write_result "$REGION" CLOUDWATCH LOG_GROUP_ENCRYPTION Account PASS MEDIUM \
    "Log groups encrypted"
else
    write_result "$REGION" CLOUDWATCH LOG_GROUP_ENCRYPTION Account FAIL MEDIUM \
    "Log groups not encrypted"
fi

###############################################################################
# METRIC FILTERS
###############################################################################

FILTERS=$(aws logs describe-metric-filters \
    --query 'metricFilters[*].filterName' \
    --output text 2>/dev/null)

if [[ -n "$FILTERS" ]]
then
    write_result "$REGION" CLOUDWATCH METRIC_FILTERS Account PASS LOW \
    "Metric filters configured"
else
    write_result "$REGION" CLOUDWATCH METRIC_FILTERS Account FAIL LOW \
    "No metric filters configured"
fi

###############################################################################
# COMPOSITE ALARMS
###############################################################################

COMPOSITE=$(aws cloudwatch describe-alarms \
    --query 'CompositeAlarms[*].AlarmName' \
    --output text 2>/dev/null)

if [[ -n "$COMPOSITE" ]]
then
    write_result "$REGION" CLOUDWATCH COMPOSITE_ALARMS Account PASS LOW \
    "Composite alarms configured"
else
    write_result "$REGION" CLOUDWATCH COMPOSITE_ALARMS Account FAIL LOW \
    "No composite alarms configured"
fi

###############################################################################
# ANOMALY DETECTION
###############################################################################

ANOMALY=$(aws cloudwatch describe-anomaly-detectors \
    --query 'AnomalyDetectors[*].MetricName' \
    --output text 2>/dev/null)

if [[ -n "$ANOMALY" ]]
then
    write_result "$REGION" CLOUDWATCH ANOMALY_DETECTION Account PASS LOW \
    "Anomaly detection configured"
else
    write_result "$REGION" CLOUDWATCH ANOMALY_DETECTION Account FAIL LOW \
    "No anomaly detection configured"
fi

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
    CLOUDWATCH \
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
echo "CloudWatch Audit Complete"
