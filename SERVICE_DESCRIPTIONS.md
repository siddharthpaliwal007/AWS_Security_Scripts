# AWS Security Audit Framework - Service Descriptions

## Overview

This document provides a summary of security checks performed by each service module in the AWS Security Audit Framework.

Each script performs read-only AWS security assessments and generates CSV and HTML reports.

---

# IAM (Identity and Access Management)

Script:

`check-iam.sh`

Checks:

- Root account MFA status
- Root access key usage
- IAM user MFA configuration
- Password policy configuration
- Old access keys
- Unused access keys
- High privilege user permissions
- AdministratorAccess policies
- IAMFullAccess policies
- Privileged IAM roles

---

# CloudTrail

Script:

`check-cloudtrail.sh`

Checks:

- CloudTrail enabled status
- Multi-region trail configuration
- Log file validation
- CloudWatch Logs integration
- Trail encryption status
- S3 logging configuration

---

# Amazon S3

Script:

`check-s3.sh`

Checks:

- Public bucket access
- Bucket encryption status
- Versioning configuration
- MFA delete configuration
- Bucket logging status
- Bucket policy review

---

# EC2

Script:

`check-ec2.sh`

Checks:

- Instance security configuration
- Public exposure checks
- Instance state review
- IMDS configuration
- Monitoring configuration
- Instance metadata settings

---

# Security Groups

Script:

`check-security-groups.sh`

Checks:

- Open inbound ports
- Public SSH exposure
- Public RDP exposure
- Wide CIDR access rules
- Unrestricted security groups

---

# VPC

Script:

`check-vpc.sh`

Checks:

- VPC configuration review
- Subnet configuration
- Route table checks
- Internet Gateway exposure
- Network configuration review

---

# RDS

Script:

`check-rds.sh`

Checks:

- Public database exposure
- Encryption status
- Backup configuration
- Deletion protection
- Multi-AZ configuration
- Database security settings

---

# Lambda

Script:

`check-lambda.sh`

Checks:

- Function configuration
- Runtime versions
- Environment variable review
- Function permissions
- Public access checks

---

# EBS

Script:

`check-ebs.sh`

Checks:

- Volume encryption status
- Unattached volumes
- Snapshot exposure
- Storage security configuration

---

# CloudFormation

Script:

`check-cloudformation.sh`

Checks:

- Stack status
- Termination protection
- Template configuration
- Stack security review

---

# CloudWatch

Script:

`check-cloudwatch.sh`

Checks:

- Log group configuration
- Log retention settings
- Monitoring configuration
- Alarm availability

---

# AWS Config

Script:

`check-config.sh`

Checks:

- Config recorder status
- Delivery channel configuration
- Compliance monitoring status

---

# KMS

Script:

`check-kms.sh`

Checks:

- Key rotation status
- Key status
- Customer managed keys
- Key configuration review

---

# SNS

Script:

`check-sns.sh`

Checks:

- Topic encryption
- Public access policies
- Topic configuration

---

# SQS

Script:

`check-sqs.sh`

Checks:

- Queue encryption
- Access policy review
- Public access configuration

---

# Secrets Manager

Script:

`check-secretsmanager.sh`

Checks:

- Secret rotation status
- Encryption configuration
- Secret age review

---

# ECR

Script:

`check-ecr.sh`

Checks:

- Repository scanning
- Image security settings
- Encryption configuration
- Repository policies

---

# ECS

Script:

`check-ecs.sh`

Checks:

- Cluster configuration
- Service security settings
- Task definition review
- Container configuration

---

# EKS

Script:

`check-eks.sh`

Checks:

- Cluster security configuration
- Endpoint access settings
- Kubernetes version review
- Logging configuration

---

# GuardDuty

Script:

`check-guardduty.sh`

Checks:

- GuardDuty enabled status
- Detector configuration
- Threat monitoring availability

---

# Security Hub

Script:

`check-securityhub.sh`

Checks:

- Security Hub enabled status
- Security standards configuration
- Finding aggregation status

---

# Macie

Script:

`check-macie.sh`

Checks:

- Macie enabled status
- Sensitive data discovery configuration
- Account configuration

---

# Route 53

Script:

`check-route53.sh`

Checks:

- Hosted zone configuration
- DNS security settings
- Domain configuration review

---

# Elastic Load Balancer

Script:

`check-elb.sh`

Checks:

- Load balancer configuration
- HTTPS listener usage
- SSL/TLS configuration
- Public exposure checks

---

# ACM

Script:

`check-acm.sh`

Checks:

- Certificate status
- Expired certificates
- Certificate validation

---

# Redshift

Script:

`check-redshift.sh`

Checks:

- Cluster encryption
- Public accessibility
- Backup configuration
- Security settings

---

# DynamoDB

Script:

`check-dynamodb.sh`

Checks:

- Table encryption
- Backup configuration
- Point-in-time recovery status

---

# ElastiCache

Script:

`check-elasticache.sh`

Checks:

- Encryption configuration
- Cluster security settings
- Backup configuration

---

# AWS Organizations

Script:

`check-organizations.sh`

Checks:

- Organization configuration
- Account structure
- Service control policy review

---

# Access Analyzer

Script:

`check-access-analyzer.sh`

Checks:

- Analyzer status
- External access findings
- Resource exposure checks

---

# Inspector

Script:

`check-inspector.sh`

Checks:

- Inspector enabled status
- Vulnerability scanning status
- Assessment configuration

---

# WAF & Shield

Script:

`check-waf.sh`

Checks:

- Web ACL configuration
- Rule configuration
- Protection status

---

# AWS Backup

Script:

`check-backup.sh`

Checks:

- Backup vault configuration
- Backup plans
- Backup protection status

---

# Summary

The AWS Security Audit Framework provides security visibility across:

- Identity Security
- Network Security
- Data Protection
- Encryption
- Logging & Monitoring
- Threat Detection
- Backup & Recovery
- Compliance Configuration

All checks are performed using AWS read-only operations.
