# AWS Security Audit Framework

## Overview

AWS Security Audit Framework is a lightweight, production-safe security assessment framework built using Bash and AWS CLI.

It helps evaluate the security posture of AWS environments by performing automated checks across multiple AWS services and generating easy-to-review security reports.

The framework is designed to be:

- Production Safe
- Read Only
- AWS CLI Based
- Modular
- Lightweight
- CloudShell Compatible
- Easy to Extend

The framework does not modify, delete, or update AWS resources. It only performs security checks using AWS read APIs.

The framework generates:

- CSV Reports
- HTML Reports
- Consolidated Security Dashboard
- Optional Amazon S3 Report Uploads


## Supported AWS Services

The framework currently supports security audits for the following AWS services:

- IAM
- CloudTrail
- S3
- EC2
- Security Groups
- VPC
- RDS
- Lambda
- EBS
- CloudFormation
- CloudWatch
- AWS Config
- KMS
- SNS
- SQS
- Secrets Manager
- ECR
- ECS
- EKS
- GuardDuty
- Security Hub
- Macie
- Route 53
- Elastic Load Balancer (ALB/NLB)
- ACM
- Redshift
- DynamoDB
- ElastiCache
- AWS Organizations
- Access Analyzer
- Inspector
- WAF & Shield
- AWS Backup

For detailed information about what each service audit checks, see:

```
SERVICE_DESCRIPTIONS.md
```

# Getting Started

## 1. Clone the Repository

Open AWS CloudShell or any Linux environment configured with AWS CLI access.

Clone the project:

```bash
git clone https://github.com/siddharthpaliwal007/AWS_Security_Scripts.git
```

Move into the project directory:

```bash
cd AWS_Security_Framework
```


## 2. Provide Execute Permission

Make all framework scripts executable:

```bash
chmod +x *.sh
```


## 3. Run Complete AWS Security Assessment

To scan all supported AWS services, execute:

```bash
./run-all.sh
```

This is the recommended execution method.

The master script will automatically:

- Validate AWS CLI configuration
- Verify AWS authentication
- Execute initialization if required
- Run all service audit scripts
- Continue execution even if one service check fails
- Generate individual service reports
- Generate consolidated security dashboard
- Upload reports to S3 (if enabled)


Execution example:

```
============================================================
 AWS SECURITY AUDIT FRAMEWORK
============================================================
...

AWS SECURITY AUDIT COMPLETED
```

# Running Individual Service Audit

Individual service checks can also be executed separately.

First initialize the framework:

```bash
./bootstrap.sh
```

Then execute the required service audit script.

Example:

IAM Audit:

```bash
./check-iam.sh
```

All service scripts follow the same naming format:

```bash
./check-<service-name>.sh
```


# Reports

## Local Reports

After successful execution, reports are generated inside:

```
reports/
```
Example:

```
reports/

├── iam-report.csv
├── iam-report.html

└── master-security-dashboard.html
```

Each service generates:

### CSV Report

Contains raw security findings:

- Account ID
- Region
- Service
- Check Name
- Resource
- Status
- Severity
- Details


### HTML Report

Provides an interactive security dashboard containing:

- Summary cards
- Search
- Filters
- PASS / FAIL status
- Severity levels
- Detailed findings


## Amazon S3 Report Upload

If automatic upload is enabled, reports are uploaded to the configured S3 bucket.

Example structure:

```
s3://security-report-bucket/
└── Account-ID/
    └── Date/
        ├── iam/
        │
        │
        └── master-security-dashboard.html
```

The upload location is displayed after successful execution.

# Troubleshooting

## AWS Authentication Failure

Verify AWS credentials:

```bash
aws sts get-caller-identity
```

Ensure the configured IAM user or role has required read permissions.

## Permission Denied While Running Scripts

Provide execute permission again:

```bash
chmod +x *.sh
```


## Missing Configuration File

Re-run initialization:

```bash
./bootstrap.sh
```

## Reports Are Not Uploaded To S3

Verify:

- S3 bucket exists
- AWS permissions are available
- Upload configuration is enabled

## Script Execution Issues

Check framework logs:

```
logs/
```

The master execution log is available at:

```
logs/run-all.log
```

# Project Structure

```
AWS_Security_Framework/

├── bootstrap.sh
├── common.sh
├── run-all.sh
├── config.conf

├── check-iam.sh
├── check-s3.sh
├── ...

├── reports/
└── logs/
```

# Security Notice

This framework performs read-only security assessments.

It does not:

- Delete resources
- Modify configurations
- Enable or disable AWS services
- Change IAM permissions

All checks are performed using AWS CLI read operations.
