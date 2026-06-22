#!/bin/bash

set -uo pipefail

export TZ=Asia/Kolkata
DATE=$(date '+%Y-%m-%d %H:%M:%S IST')
DATE_FOLDER=$(date '+%Y-%m-%d')

ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text 2>/dev/null)

create_report_dir() {
    mkdir -p reports
}

###############################################################################
# CSV
###############################################################################

init_csv() {

    REPORT_FILE="$1"

    echo "Timestamp,AccountId,Region,Service,Check,Resource,Status,Severity,Details" \
    > "$REPORT_FILE"

}

write_result() {

    local REGION="$1"
    local SERVICE="$2"
    local CHECK="$3"
    local RESOURCE="$4"
    local STATUS="$5"
    local SEVERITY="$6"
    local DETAILS="$7"

    echo "\"$DATE\",\"$ACCOUNT_ID\",\"$REGION\",\"$SERVICE\",\"$CHECK\",\"$RESOURCE\",\"$STATUS\",\"$SEVERITY\",\"$DETAILS\"" \
    >> "$REPORT_FILE"

}

###############################################################################
# HTML REPORT
###############################################################################

generate_html() {

    local CSV="$1"
    local HTML="$2"

    PASS_COUNT=$(awk -F',' '$7 ~ /PASS/ {count++} END {print count+0}' "$CSV")
    FAIL_COUNT=$(awk -F',' '$7 ~ /FAIL/ {count++} END {print count+0}' "$CSV")
    CRITICAL_COUNT=$(awk -F',' '$8 ~ /CRITICAL/ {count++} END {print count+0}' "$CSV")
    HIGH_COUNT=$(awk -F',' '$8 ~ /HIGH/ {count++} END {print count+0}' "$CSV")
    MEDIUM_COUNT=$(awk -F',' '$8 ~ /MEDIUM/ {count++} END {print count+0}' "$CSV")
    LOW_COUNT=$(awk -F',' '$8 ~ /LOW/ {count++} END {print count+0}' "$CSV")
    TOTAL=$((PASS_COUNT + FAIL_COUNT))

    cat > "$HTML" <<EOF
<!DOCTYPE html>
<html>
<head>

<title>AWS Security Assessment Report</title>

<style>

body{
font-family:'Segoe UI',Arial,sans-serif;
background:#f4f6fb;
margin:0;
color:#333;
transition:.3s;
}

body.dark{
background:#1f1f1f;
color:#eee;
}

.header{
background:#232F3E;
color:white;
padding:25px;
text-align:center;
}

.container{
padding:20px;
}

.cards{
display:flex;
flex-wrap:wrap;
gap:20px;
margin-bottom:20px;
}

.card{
background:white;
padding:20px;
border-radius:15px;
box-shadow:0 2px 10px rgba(0,0,0,.1);
min-width:220px;
}

.dark .card{
background:#2d2d2d;
}

.card-title{
font-size:12px;
color:#777;
text-transform:uppercase;
}

.card-value{
font-size:24px;
font-weight:bold;
margin-top:10px;
}

.filters{
background:white;
padding:20px;
border-radius:15px;
margin-bottom:20px;
box-shadow:0 2px 10px rgba(0,0,0,.1);
}

.dark .filters{
background:#2d2d2d;
}

input,select,button{
padding:10px;
border-radius:8px;
border:1px solid #ccc;
margin-right:10px;
margin-bottom:10px;
}

button{
background:#232F3E;
color:white;
cursor:pointer;
}

.table-container{
overflow:auto;
background:white;
border-radius:15px;
box-shadow:0 2px 10px rgba(0,0,0,.1);
}

.dark .table-container{
background:#2d2d2d;
}

table{
width:100%;
border-collapse:collapse;
}

th{
background:#232F3E;
color:white;
padding:12px;
position:sticky;
top:0;
}

td{
padding:10px;
border-bottom:1px solid #ddd;
}

.pass{
background:#28a745;
color:white;
padding:4px 12px;
border-radius:15px;
}

.fail{
background:#dc3545;
color:white;
padding:4px 12px;
border-radius:15px;
}

</style>

</head>

<body>

<div class="header">
<h1>AWS Security Assessment Report</h1>
</div>

<div class="container">

<div class="cards">

<div class="card">
<div class="card-title">AWS Account</div>
<div class="card-value">$ACCOUNT_ID</div>
</div>

<div class="card">
<div class="card-title">Generated</div>
<div class="card-value">$DATE</div>
</div>

<div class="card">
<div class="card-title">Total Checks</div>
<div class="card-value">$TOTAL</div>
</div>

<div class="card">
<div class="card-title">Passed</div>
<div class="card-value">$PASS_COUNT</div>
</div>

<div class="card">
<div class="card-title">Failed</div>
<div class="card-value">$FAIL_COUNT</div>
</div>

</div>

<div class="filters">

<input type="text" id="searchInput" placeholder="🔍 Search">

<select id="statusFilter">
<option value="">All Status</option>
<option>PASS</option>
<option>FAIL</option>
</select>

<select id="severityFilter">
<option value="">All Severity</option>
<option>CRITICAL</option>
<option>HIGH</option>
<option>MEDIUM</option>
<option>LOW</option>
</select>

<button onclick="toggleDarkMode()">🌙 Dark Mode</button>

<button onclick="window.print()">🖨 Print</button>

</div>

<div class="table-container">

<table id="reportTable">

<tr>
<th>Timestamp</th>
<th>AccountId</th>
<th>Region</th>
<th>Service</th>
<th>Check</th>
<th>Resource</th>
<th>Status</th>
<th>Severity</th>
<th>Details</th>
</tr>
EOF

    tail -n +2 "$CSV" | while IFS=',' read -r c1 c2 c3 c4 c5 c6 c7 c8 c9
    do

        STATUS=$(echo "$c7" | tr -d '"')
        SEVERITY=$(echo "$c8" | tr -d '"')

        STATUS_BADGE="$STATUS"

        if [[ "$STATUS" == "PASS" ]]
        then
            STATUS_BADGE="<span class='pass'>PASS</span>"
        else
            STATUS_BADGE="<span class='fail'>FAIL</span>"
        fi

        cat >> "$HTML" <<EOF
<tr>
<td>$c1</td>
<td>$c2</td>
<td>$c3</td>
<td>$c4</td>
<td>$c5</td>
<td>$c6</td>
<td>$STATUS_BADGE</td>
<td>$SEVERITY</td>
<td>$c9</td>
</tr>
EOF

    done

    cat >> "$HTML" <<'EOF'

</table>

</div>

<script>

function toggleDarkMode(){
document.body.classList.toggle("dark");
}

const searchInput=document.getElementById("searchInput");
const statusFilter=document.getElementById("statusFilter");
const severityFilter=document.getElementById("severityFilter");

searchInput.addEventListener("keyup",filterTable);
statusFilter.addEventListener("change",filterTable);
severityFilter.addEventListener("change",filterTable);

function filterTable(){

let search=searchInput.value.toUpperCase();
let status=statusFilter.value;
let severity=severityFilter.value;

let rows=document.querySelectorAll("#reportTable tr");

for(let i=1;i<rows.length;i++){

let row=rows[i];

let text=row.innerText.toUpperCase();

let rowStatus=row.cells[6].innerText.trim();
let rowSeverity=row.cells[7].innerText.trim();

let show=true;

if(search!=="" && text.indexOf(search)==-1)
show=false;

if(status!=="" && rowStatus!==status)
show=false;

if(severity!=="" && rowSeverity!==severity)
show=false;

row.style.display=show?"":"none";

}

}

</script>

</div>

</body>
</html>

EOF
}

###############################################################################
# REPORT BUCKET VALIDATION
###############################################################################

validate_bucket() {

    [[ "${AUTO_UPLOAD:-false}" != "true" ]] && return 0

    aws s3api head-bucket \
        --bucket "$REPORT_BUCKET" \
        >/dev/null 2>&1

    if [[ $? -eq 0 ]]
    then
        return 0
    fi

    echo
    echo "Report bucket missing."
    echo "Running bootstrap.sh..."
    echo

    chmod +x bootstrap.sh
    ./bootstrap.sh >/dev/null 2>&1

    aws s3api head-bucket \
        --bucket "$REPORT_BUCKET" \
        >/dev/null 2>&1

    if [[ $? -eq 0 ]]
    then

        echo
        echo "Report bucket recreated successfully"
        echo

        return 0

    fi

    echo
    echo "ERROR: Unable to create report bucket"
    echo

    return 1

}

###############################################################################
# REPORT UPLOAD
###############################################################################

upload_reports() {

    [[ "${AUTO_UPLOAD:-false}" != "true" ]] && return 0

    local SERVICE="$1"
    local CSV_FILE="$2"
    local HTML_FILE="$3"

    PREFIX="$ACCOUNT_ID/$DATE_FOLDER/$SERVICE"

    aws s3 cp \
        "$CSV_FILE" \
        "s3://$REPORT_BUCKET/$PREFIX/" \
        >/dev/null

    CSV_STATUS=$?

    aws s3 cp \
        "$HTML_FILE" \
        "s3://$REPORT_BUCKET/$PREFIX/" \
        >/dev/null

    HTML_STATUS=$?

    if [[ $CSV_STATUS -eq 0 && $HTML_STATUS -eq 0 ]]
    then

        echo
        echo "Reports Uploaded Successfully"
        echo

        echo "CSV:"
        echo "s3://$REPORT_BUCKET/$PREFIX/$(basename "$CSV_FILE")"
        echo

        echo "HTML:"
        echo "s3://$REPORT_BUCKET/$PREFIX/$(basename "$HTML_FILE")"
        echo

    else

        echo
        echo "ERROR: Report upload failed"
        echo

        return 1

    fi

}

###############################################################################
# REGIONS
###############################################################################

get_regions() {

    aws ec2 describe-regions \
        --query 'Regions[*].RegionName' \
        --output text 2>/dev/null

}
