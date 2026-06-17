# Service Descriptions

## Overview

This document describes the purpose of each script currently available in the AWS Security Audit Framework.

The framework is designed to perform AWS security assessments and generate easy-to-understand reports in both CSV and HTML formats.

---

# bootstrap.sh

## Purpose

The bootstrap script prepares the environment before any security audits are executed.

This script should be run once during the initial setup.

## What it does

* Verifies AWS access
* Detects AWS Account ID
* Creates the report storage bucket (if required)
* Creates local report folders
* Generates the configuration file (`config.conf`)
* Prepares the framework for future audit scripts

## When to run

Run before executing any audit script.

Example:

```bash
./bootstrap.sh
```

---

# common.sh

## Purpose

This file contains common functions shared by all audit scripts.

It is the core utility library used throughout the framework.

## What it does

* Creates report directories
* Generates CSV reports
* Generates HTML reports
* Formats audit results
* Validates report bucket availability
* Uploads reports to Amazon S3
* Handles common framework functions

## Important

This file is **not executed directly**.

It is automatically used by audit scripts.

Example:

```bash
source ./common.sh
```

---

# check-iam.sh

## Service

AWS Identity and Access Management (IAM)

## Purpose

Performs security checks against IAM users, credentials, permissions, and roles.

The script helps identify common IAM security risks and privilege management issues.

## Security Checks Performed

### Root Account Security

* Root MFA enabled
* Root access keys present

### User Security

* User MFA enabled
* Unused users
* User credential review

### Password Policy

* Password policy configured

### Access Keys

* Access keys older than 90 days
* Unused access keys

### Excessive Permissions

* AdministratorAccess permissions
* IAMFullAccess permissions
* PowerUserAccess permissions

### Role Policy Review

* Roles with AdministratorAccess
* Roles with IAMFullAccess

## Report Output

The script generates:

```text
reports/
├── iam-report.csv
└── iam-report.html
```

If automatic uploads are enabled, reports are also uploaded to the configured Amazon S3 report bucket.

## Example

Run the IAM audit:

```bash
./check-iam.sh
```

---

# Future Services

Additional AWS service audit scripts will be added over time.

Examples include:

* CloudTrail
* S3
* EC2
* RDS
* CloudWatch
* AWS Config
* KMS
* ECR
* ECS
* GuardDuty
* Security Hub
* WAF
* And other AWS services

This document will be updated as new audit scripts are introduced.

---

# Current Framework Version

Version: 1.0

Current Scripts:

* bootstrap.sh
* common.sh
* check-iam.sh
