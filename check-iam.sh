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

SERVICE="IAM"

create_report_dir

REPORT_FILE="reports/iam-report.csv"
HTML_FILE="reports/iam-report.html"

init_csv "$REPORT_FILE"

###############################################################################
# ROOT MFA
###############################################################################

ROOT_MFA=$(aws iam get-account-summary \
    --query 'SummaryMap.AccountMFAEnabled' \
    --output text 2>/dev/null)

if [[ "$ROOT_MFA" == "1" ]]
then
    write_result global IAM ROOT_MFA Root PASS CRITICAL "Root MFA enabled"
else
    write_result global IAM ROOT_MFA Root FAIL CRITICAL "Root MFA NOT enabled"
fi

###############################################################################
# ROOT ACCESS KEYS
###############################################################################

ROOT_KEYS=$(aws iam get-account-summary \
    --query 'SummaryMap.AccountAccessKeysPresent' \
    --output text 2>/dev/null)

if [[ "$ROOT_KEYS" == "0" ]]
then
    write_result global IAM ROOT_ACCESS_KEYS Root PASS HIGH "No root access keys"
else
    write_result global IAM ROOT_ACCESS_KEYS Root FAIL HIGH "Root access keys present"
fi

###############################################################################
# PASSWORD POLICY
###############################################################################

if aws iam get-account-password-policy >/dev/null 2>&1
then
    write_result global IAM PASSWORD_POLICY Account PASS MEDIUM "Password policy configured"
else
    write_result global IAM PASSWORD_POLICY Account FAIL MEDIUM "Password policy missing"
fi

###############################################################################
# IAM USERS
###############################################################################

USERS=$(aws iam list-users \
    --query 'Users[*].UserName' \
    --output text 2>/dev/null)

for USER in $USERS
do

    MFA=$(aws iam list-mfa-devices \
        --user-name "$USER" \
        --query 'MFADevices[*].SerialNumber' \
        --output text 2>/dev/null)

    if [[ -z "$MFA" ]]
    then
        write_result global IAM USER_MFA "$USER" FAIL HIGH "User without MFA"
    else
        write_result global IAM USER_MFA "$USER" PASS LOW "MFA enabled"
    fi

done

###############################################################################
# ACCESS KEYS OLDER THAN 90 DAYS
###############################################################################

for USER in $USERS
do

    aws iam list-access-keys \
        --user-name "$USER" \
        --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate]' \
        --output text 2>/dev/null |

    while read KEY CREATED
    do

        [[ -z "$KEY" ]] && continue

        AGE=$(( ($(date +%s) - $(date -d "$CREATED" +%s)) / 86400 ))

        if (( AGE > 90 ))
        then
            write_result global IAM OLD_ACCESS_KEY "$KEY" FAIL HIGH \
            "Access key age=$AGE days"
        else
            write_result global IAM OLD_ACCESS_KEY "$KEY" PASS LOW \
            "Access key age=$AGE days"
        fi

    done

done

###############################################################################
# UNUSED ACCESS KEYS
###############################################################################

for USER in $USERS
do

    KEYS=$(aws iam list-access-keys \
        --user-name "$USER" \
        --query 'AccessKeyMetadata[*].AccessKeyId' \
        --output text 2>/dev/null)

    for KEY in $KEYS
    do

        LAST_USED=$(aws iam get-access-key-last-used \
            --access-key-id "$KEY" \
            --query 'AccessKeyLastUsed.LastUsedDate' \
            --output text 2>/dev/null)

        if [[ "$LAST_USED" == "None" ]]
        then
            write_result global IAM UNUSED_ACCESS_KEY "$KEY" FAIL HIGH \
            "Access key never used"
        else
            write_result global IAM UNUSED_ACCESS_KEY "$KEY" PASS LOW \
            "Access key has been used"
        fi

    done

done

###############################################################################
# ADMINISTRATOR ACCESS
###############################################################################

for USER in $USERS
do

    POLICIES=$(aws iam list-attached-user-policies \
        --user-name "$USER" \
        --query 'AttachedPolicies[*].PolicyName' \
        --output text 2>/dev/null)

    if echo "$POLICIES" | grep -q "AdministratorAccess"
    then
        write_result global IAM ADMIN_ACCESS "$USER" FAIL HIGH \
        "AdministratorAccess attached"
    fi

done

###############################################################################
# IAM FULL ACCESS / POWER USER ACCESS
###############################################################################

for USER in $USERS
do

    POLICIES=$(aws iam list-attached-user-policies \
        --user-name "$USER" \
        --query 'AttachedPolicies[*].PolicyName' \
        --output text 2>/dev/null)

    if echo "$POLICIES" | grep -q "IAMFullAccess"
    then
        write_result global IAM IAM_FULL_ACCESS "$USER" FAIL HIGH \
        "IAMFullAccess attached"
    fi

    if echo "$POLICIES" | grep -q "PowerUserAccess"
    then
        write_result global IAM POWER_USER_ACCESS "$USER" FAIL MEDIUM \
        "PowerUserAccess attached"
    fi

done

###############################################################################
# ROLE POLICY AUDIT
###############################################################################

ROLES=$(aws iam list-roles \
    --query 'Roles[*].RoleName' \
    --output text 2>/dev/null)

for ROLE in $ROLES
do

    ROLE_POLICIES=$(aws iam list-attached-role-policies \
        --role-name "$ROLE" \
        --query 'AttachedPolicies[*].PolicyName' \
        --output text 2>/dev/null)

    if echo "$ROLE_POLICIES" | grep -q "AdministratorAccess"
    then
        write_result global IAM ROLE_ADMIN_ACCESS "$ROLE" FAIL HIGH \
        "Role has AdministratorAccess"
    fi

    if echo "$ROLE_POLICIES" | grep -q "IAMFullAccess"
    then
        write_result global IAM ROLE_IAM_FULL_ACCESS "$ROLE" FAIL HIGH \
        "Role has IAMFullAccess"
    fi

done

###############################################################################
# UNUSED USERS (CREDENTIAL REPORT)
###############################################################################

aws iam generate-credential-report >/dev/null 2>&1

sleep 2

aws iam get-credential-report \
    --query 'Content' \
    --output text 2>/dev/null | base64 -d > /tmp/credential-report.csv

grep -v "^<root_account>" /tmp/credential-report.csv | tail -n +2 |

while IFS=',' read USERNAME PASSWORD_ENABLED PASSWORD_LAST_USED REST
do

    if [[ "$PASSWORD_LAST_USED" == "N/A" ]]
    then

        write_result global IAM UNUSED_USER "$USERNAME" FAIL MEDIUM \
        "User never logged in"

    else

        write_result global IAM UNUSED_USER "$USERNAME" PASS LOW \
        "User has logged in"

    fi

done

rm -f /tmp/credential-report.csv

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
    IAM \
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
echo "IAM Audit Complete"
echo
