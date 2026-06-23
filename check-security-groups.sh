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

SERVICE="SECURITY_GROUP"

create_report_dir

REPORT_FILE="reports/security-group-report.csv"
HTML_FILE="reports/security-group-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# SECURITY GROUP CHECKS
###############################################################################

SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].GroupId' \
    --output text 2>/dev/null)

for SG in $SECURITY_GROUPS
do

    REGION="$DEFAULT_REGION"

###############################################################################
# OPEN SSH
###############################################################################

    SSH_OPEN=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && ToPort==\`22\`].IpRanges[?CidrIp=='0.0.0.0/0']" \
        --output text 2>/dev/null)

    if [[ -n "$SSH_OPEN" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_OPEN_SSH "$SG" FAIL CRITICAL \
        "SSH open to 0.0.0.0/0"
    else
        write_result "$REGION" SECURITY_GROUP SG_OPEN_SSH "$SG" PASS CRITICAL \
        "SSH not exposed"
    fi

###############################################################################
# OPEN RDP
###############################################################################

    RDP_OPEN=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`3389\` && ToPort==\`3389\`].IpRanges[?CidrIp=='0.0.0.0/0']" \
        --output text 2>/dev/null)

    if [[ -n "$RDP_OPEN" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_OPEN_RDP "$SG" FAIL CRITICAL \
        "RDP open to 0.0.0.0/0"
    else
        write_result "$REGION" SECURITY_GROUP SG_OPEN_RDP "$SG" PASS CRITICAL \
        "RDP not exposed"
    fi

###############################################################################
# OPEN ALL TCP
###############################################################################

    ALL_TCP=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissions[?IpProtocol=='tcp' && FromPort==\`0\` && ToPort==\`65535\`].IpRanges[?CidrIp=='0.0.0.0/0']" \
        --output text 2>/dev/null)

    if [[ -n "$ALL_TCP" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_OPEN_ALL_TCP "$SG" FAIL HIGH \
        "All TCP ports open"
    else
        write_result "$REGION" SECURITY_GROUP SG_OPEN_ALL_TCP "$SG" PASS HIGH \
        "All TCP ports restricted"
    fi

###############################################################################
# OPEN ALL UDP
###############################################################################

    ALL_UDP=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissions[?IpProtocol=='udp' && FromPort==\`0\` && ToPort==\`65535\`].IpRanges[?CidrIp=='0.0.0.0/0']" \
        --output text 2>/dev/null)

    if [[ -n "$ALL_UDP" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_OPEN_ALL_UDP "$SG" FAIL HIGH \
        "All UDP ports open"
    else
        write_result "$REGION" SECURITY_GROUP SG_OPEN_ALL_UDP "$SG" PASS HIGH \
        "All UDP ports restricted"
    fi

###############################################################################
# OPEN ALL PROTOCOLS
###############################################################################

    ALL_PROTOCOLS=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissions[?IpProtocol=='-1'].IpRanges[?CidrIp=='0.0.0.0/0']" \
        --output text 2>/dev/null)

    if [[ -n "$ALL_PROTOCOLS" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_OPEN_ALL_PROTOCOLS "$SG" FAIL CRITICAL \
        "All protocols open to internet"
    else
        write_result "$REGION" SECURITY_GROUP SG_OPEN_ALL_PROTOCOLS "$SG" PASS CRITICAL \
        "No unrestricted protocols"

    fi

###############################################################################
# UNUSED SECURITY GROUP
###############################################################################

    ENI_COUNT=$(aws ec2 describe-network-interfaces \
        --filters Name=group-id,Values="$SG" \
        --query 'length(NetworkInterfaces)' \
        --output text 2>/dev/null)

    if [[ "$ENI_COUNT" -eq 0 ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_UNUSED "$SG" FAIL LOW \
        "Security group not attached to any interface"
    else
        write_result "$REGION" SECURITY_GROUP SG_UNUSED "$SG" PASS LOW \
        "Security group in use"
    fi

###############################################################################
# EGRESS ALL
###############################################################################

    EGRESS_ALL=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissionsEgress[?IpProtocol=='-1'].IpRanges[?CidrIp=='0.0.0.0/0']" \
        --output text 2>/dev/null)

    if [[ -n "$EGRESS_ALL" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_EGRESS_ALL "$SG" FAIL LOW \
        "Allow all outbound traffic"
    else
        write_result "$REGION" SECURITY_GROUP SG_EGRESS_ALL "$SG" PASS LOW \
        "Restricted outbound rules"
    fi

###############################################################################
# SELF REFERENCE
###############################################################################

    SELF_REF=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query "SecurityGroups[0].IpPermissions[].UserIdGroupPairs[?GroupId=='$SG']" \
        --output text 2>/dev/null)

    if [[ -n "$SELF_REF" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_SELF_REFERENCE "$SG" FAIL LOW \
        "Self-referencing rule exists"
    else
        write_result "$REGION" SECURITY_GROUP SG_SELF_REFERENCE "$SG" PASS LOW \
        "No self-referencing rules"
    fi

###############################################################################
# RULE COUNT
###############################################################################

    RULE_COUNT=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query 'length(SecurityGroups[0].IpPermissions)' \
        --output text 2>/dev/null)

    if [[ "$RULE_COUNT" -gt 50 ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_RULE_COUNT "$SG" FAIL LOW \
        "Too many inbound rules ($RULE_COUNT)"
    else
        write_result "$REGION" SECURITY_GROUP SG_RULE_COUNT "$SG" PASS LOW \
        "Rule count acceptable ($RULE_COUNT)"
    fi

###############################################################################
# RULE DESCRIPTIONS
###############################################################################

    NO_DESC=$(aws ec2 describe-security-groups \
        --group-ids "$SG" \
        --query 'SecurityGroups[0].IpPermissions[].IpRanges[?Description==null]' \
        --output text 2>/dev/null)

    if [[ -n "$NO_DESC" ]]
    then
        write_result "$REGION" SECURITY_GROUP SG_NO_DESCRIPTION "$SG" FAIL LOW \
        "One or more rules missing description"
    else
        write_result "$REGION" SECURITY_GROUP SG_NO_DESCRIPTION "$SG" PASS LOW \
        "All rules documented"
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
    SECURITY_GROUP \
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
echo "Security Group Audit Complete"

