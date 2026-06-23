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

SERVICE="VPC"

create_report_dir

REPORT_FILE="reports/vpc-report.csv"
HTML_FILE="reports/vpc-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# VPC CHECKS
###############################################################################

VPCS=$(aws ec2 describe-vpcs \
    --query 'Vpcs[*].VpcId' \
    --output text 2>/dev/null)

for VPC in $VPCS
do

    REGION="$DEFAULT_REGION"

###############################################################################
# FLOW LOGS
###############################################################################

    FLOW_LOGS=$(aws ec2 describe-flow-logs \
        --filter Name=resource-id,Values="$VPC" \
        --query 'FlowLogs[*].FlowLogId' \
        --output text 2>/dev/null)

    if [[ -n "$FLOW_LOGS" ]]
    then
        write_result "$REGION" VPC VPC_FLOW_LOGS "$VPC" PASS HIGH \
        "Flow logs enabled"
    else
        write_result "$REGION" VPC VPC_FLOW_LOGS "$VPC" FAIL HIGH \
        "Flow logs not enabled"
    fi

###############################################################################
# INTERNET GATEWAY
###############################################################################

    IGW=$(aws ec2 describe-internet-gateways \
        --filters Name=attachment.vpc-id,Values="$VPC" \
        --query 'InternetGateways[*].InternetGatewayId' \
        --output text 2>/dev/null)

    if [[ -n "$IGW" ]]
    then
        write_result "$REGION" VPC INTERNET_GATEWAY "$VPC" PASS LOW \
        "Internet gateway attached"
    else
        write_result "$REGION" VPC INTERNET_GATEWAY "$VPC" FAIL LOW \
        "No internet gateway attached"
    fi

###############################################################################
# DEFAULT VPC
###############################################################################

    DEFAULT_VPC=$(aws ec2 describe-vpcs \
        --vpc-ids "$VPC" \
        --query 'Vpcs[0].IsDefault' \
        --output text 2>/dev/null)

    if [[ "$DEFAULT_VPC" == "True" ]]
    then
        write_result "$REGION" VPC DEFAULT_VPC "$VPC" FAIL LOW \
        "Default VPC detected"
    else
        write_result "$REGION" VPC DEFAULT_VPC "$VPC" PASS LOW \
        "Non-default VPC"
    fi

###############################################################################
# DNS SUPPORT
###############################################################################

    DNS_SUPPORT=$(aws ec2 describe-vpc-attribute \
        --vpc-id "$VPC" \
        --attribute enableDnsSupport \
        --query 'EnableDnsSupport.Value' \
        --output text 2>/dev/null)

    if [[ "$DNS_SUPPORT" == "True" ]]
    then
        write_result "$REGION" VPC DNS_SUPPORT "$VPC" PASS LOW \
        "DNS support enabled"
    else
        write_result "$REGION" VPC DNS_SUPPORT "$VPC" FAIL LOW \
        "DNS support disabled"
    fi

###############################################################################
# DNS HOSTNAMES
###############################################################################

    DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute \
        --vpc-id "$VPC" \
        --attribute enableDnsHostnames \
        --query 'EnableDnsHostnames.Value' \
        --output text 2>/dev/null)

    if [[ "$DNS_HOSTNAMES" == "True" ]]
    then
        write_result "$REGION" VPC DNS_HOSTNAMES "$VPC" PASS LOW \
        "DNS hostnames enabled"
    else
        write_result "$REGION" VPC DNS_HOSTNAMES "$VPC" FAIL LOW \
        "DNS hostnames disabled"
    fi

###############################################################################
# PUBLIC SUBNETS
###############################################################################

    PUBLIC_SUBNETS=$(aws ec2 describe-route-tables \
        --filters Name=vpc-id,Values="$VPC" \
        --query "RouteTables[].Routes[?GatewayId!=null && DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
        --output text 2>/dev/null)

    if echo "$PUBLIC_SUBNETS" | grep -q "igw-"
    then
        write_result "$REGION" VPC PUBLIC_SUBNET "$VPC" FAIL HIGH \
        "Public subnet route to Internet Gateway detected"
    else
        write_result "$REGION" VPC PUBLIC_SUBNET "$VPC" PASS HIGH \
        "No public subnet route detected"
    fi

###############################################################################
# DEFAULT NETWORK ACL
###############################################################################

    DEFAULT_NACL=$(aws ec2 describe-network-acls \
        --filters Name=vpc-id,Values="$VPC" Name=default,Values=true \
        --query 'NetworkAcls[0].Entries[?RuleAction==`allow`]' \
        --output text 2>/dev/null)

    if [[ -n "$DEFAULT_NACL" ]]
    then
        write_result "$REGION" VPC NACL_DEFAULT_ALLOW "$VPC" FAIL MEDIUM \
        "Default NACL contains allow rules"
    else
        write_result "$REGION" VPC NACL_DEFAULT_ALLOW "$VPC" PASS MEDIUM \
        "Default NACL restricted"
    fi

###############################################################################
# UNUSED ROUTE TABLES
###############################################################################

    UNUSED_RT=$(aws ec2 describe-route-tables \
        --filters Name=vpc-id,Values="$VPC" \
        --query 'RouteTables[?Associations==`[]`].RouteTableId' \
        --output text 2>/dev/null)

    if [[ -n "$UNUSED_RT" ]]
    then
        write_result "$REGION" VPC UNUSED_ROUTE_TABLE "$VPC" FAIL LOW \
        "Unused route table exists"
    else
        write_result "$REGION" VPC UNUSED_ROUTE_TABLE "$VPC" PASS LOW \
        "All route tables associated"
    fi

###############################################################################
# ROUTE TO INTERNET
###############################################################################

    INTERNET_ROUTE=$(aws ec2 describe-route-tables \
        --filters Name=vpc-id,Values="$VPC" \
        --query "RouteTables[].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
        --output text 2>/dev/null)

    if echo "$INTERNET_ROUTE" | grep -q "igw-"
    then
        write_result "$REGION" VPC ROUTE_TO_INTERNET "$VPC" FAIL HIGH \
        "Default route to Internet Gateway present"
    else
        write_result "$REGION" VPC ROUTE_TO_INTERNET "$VPC" PASS HIGH \
        "No internet route found"
    fi

###############################################################################
# MULTI-AZ SUBNETS
###############################################################################

    AZ_COUNT=$(aws ec2 describe-subnets \
        --filters Name=vpc-id,Values="$VPC" \
        --query 'Subnets[].AvailabilityZone' \
        --output text 2>/dev/null | tr '\t' '\n' | sort -u | wc -l)

    if [[ "$AZ_COUNT" -ge 2 ]]
    then
        write_result "$REGION" VPC MULTI_AZ_SUBNETS "$VPC" PASS LOW \
        "Subnets span multiple AZs"
    else
        write_result "$REGION" VPC MULTI_AZ_SUBNETS "$VPC" FAIL LOW \
        "Single AZ subnet configuration"
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
    VPC \
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
echo "VPC Audit Complete"
