#!/bin/bash

set -uo pipefail

DATE=$(date '+%Y-%m-%d %H:%M:%S')
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
ACCOUNT_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || echo "N/A")

create_report_dir() {
    mkdir -p reports
}

init_csv() {
    REPORT_FILE="$1"
    echo "Timestamp,AccountId,AccountAlias,Region,Service,Check,Resource,Status,Severity,Details" > "$REPORT_FILE"
}

write_result() {
    local REGION="$1"
    local SERVICE="$2"
    local CHECK="$3"
    local RESOURCE="$4"
    local STATUS="$5"
    local SEVERITY="$6"
    local DETAILS="$7"

    echo "\"$DATE\",\"$ACCOUNT_ID\",\"$ACCOUNT_ALIAS\",\"$REGION\",\"$SERVICE\",\"$CHECK\",\"$RESOURCE\",\"$STATUS\",\"$SEVERITY\",\"$DETAILS\"" >> "$REPORT_FILE"
}

generate_html() {
    local CSV="$1"
    local HTML="$2"

    {
        echo "<html><head><style>"
        echo "body{font-family:Arial}"
        echo "table{border-collapse:collapse;width:100%}"
        echo "th,td{border:1px solid #ddd;padding:8px}"
        echo ".PASS{background:#d4edda}"
        echo ".FAIL{background:#f8d7da}"
        echo ".WARN{background:#fff3cd}"
        echo "</style></head><body>"
        echo "<h2>AWS Security Audit Report</h2>"
        echo "<table>"

        FIRST=1
        while IFS=',' read -r c1 c2 c3 c4 c5 c6 c7 c8 c9 c10
        do
            if [[ $FIRST -eq 1 ]]; then
                echo "<tr><th>$c1</th><th>$c2</th><th>$c3</th><th>$c4</th><th>$c5</th><th>$c6</th><th>$c7</th><th>$c8</th><th>$c9</th><th>$c10</th></tr>"
                FIRST=0
                continue
            fi

            CLASS=""
            [[ "$c8" == *PASS* ]] && CLASS="PASS"
            [[ "$c8" == *FAIL* ]] && CLASS="FAIL"

            echo "<tr class='$CLASS'><td>$c1</td><td>$c2</td><td>$c3</td><td>$c4</td><td>$c5</td><td>$c6</td><td>$c7</td><td>$c8</td><td>$c9</td><td>$c10</td></tr>"
        done < "$CSV"

        echo "</table></body></html>"
    } > "$HTML"
}

upload_report() {
    local FILE="$1"
    local BUCKET="$2"
    local PREFIX="$3"

    aws s3 cp "$FILE" "s3://$BUCKET/$PREFIX/" >/dev/null 2>&1
}

service_not_found() {
    local SERVICE="$1"

    write_result \
    "global" \
    "$SERVICE" \
    "DISCOVERY" \
    "N/A" \
    "INFO" \
    "INFO" \
    "No $SERVICE service found in account"

    echo "No $SERVICE service found in account"
    exit 0
}

get_regions() {
    aws ec2 describe-regions \
    --query 'Regions[*].RegionName' \
    --output text 2>/dev/null
}
