# AWS DMS Deployment Automation

## Overview
This repository provides an automated solution to deploy AWS Database Migration Service (DMS) infrastructure using CloudFormation and a Bash deployment script. 

The primary purpose is to enable **continuous replication** from a source database to a target database based on a scheduled task. For example, you can configure the replication task to run once a week (or any other schedule) to keep your target database in sync with the source.

Key features include:
- Provisioning of DMS replication instance, endpoints, subnet and security groups
- Secure handling of database credentials
- Scheduling migration tasks using AWS Scheduler (EventBridge) to automate replication runs
- Support for PostgreSQL source and target endpoints (customizable)
- Output of key resource ARNs for easy integration and monitoring

This setup is ideal for scenarios where periodic data synchronization is required without manual intervention, leveraging AWS managed services for reliability and scalability.


---

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- Existing VPC with subnets
- Source and target database credentials (PostgreSQL)
- Bash shell environment

---

## CloudFormation Template (`dms-creation.yml`)
This template creates the following AWS resources:

- **DMS Replication Instance** (`AWS::DMS::ReplicationInstance`): The core migration engine.
- **Security Group** (`AWS::EC2::SecurityGroup`): Controls network access to the replication instance.
- **Replication Subnet Group** (`AWS::DMS::ReplicationSubnetGroup`): Defines the subnets where the replication instance will run.
- **Source and Target Endpoints** (`AWS::DMS::Endpoint`): Connection configurations for source and target databases.
- **Replication Task** (`AWS::DMS::ReplicationTask`): Defines the migration task parameters.
- **Scheduled Execution** (`AWS::Scheduler::Schedule`): Runs the migration task daily at midnight.
- **IAM Role** (`AWS::IAM::Role`): Allows the scheduler to start the replication task.

### Key Features
- Supports PostgreSQL source and target endpoints (adjust ports and engine names as needed).
- Secure handling of database passwords via CloudFormation parameters with `NoEcho`.
- Network security with restricted ingress and egress rules.
- Scheduled migration task execution using AWS Scheduler (EventBridge).
- Outputs ARNs for replication instance and migration task for easy integration.

---

## Bash Deployment Script (`deploy-dms.sh`)

### Usage

```./deploy-dms.sh -n <stack-name> -s <source-db-password> -t <target-db-password> [-r <aws-region>] [-p <aws-profile>]```


### Options
| Option | Description                                  | Required | Default          |
|--------|----------------------------------------------|----------|------------------|
| `-n`   | CloudFormation stack name                     | Yes      |                  |
| `-s`   | Source database password                       | Yes      |                  |
| `-t`   | Target database password                       | Yes      |                  |
| `-r`   | AWS region                                    | No       | `us-west-1` |
| `-p`   | AWS CLI profile                               | No       | `default`        |

### Example

```./deploy-dms.sh -n prod-dms-stack -s SrcDBPass123 -t TgtDBPass456 -r us-west-2 -p myprofile```


---

## Script Behavior
- Validates the CloudFormation template before deployment.
- Checks if the specified stack exists:
  - If it exists, prompts for confirmation before updating.
  - If it does not exist, creates a new stack.
- Deploys the stack using `aws cloudformation deploy` with necessary IAM capabilities.
- Waits for stack creation/update completion.
- Outputs key resource ARNs after deployment.
- Cleans up temporary log files.

---

## Security Considerations
- Database passwords are passed securely with `NoEcho` to prevent exposure.
- IAM Role uses least privilege for DMS task execution.
- Security group restricts inbound traffic to PostgreSQL port 5432.
- Outbound traffic is open; adjust egress rules as needed based on your environment.

---

## Best Practices
- Consider storing database credentials in AWS Secrets Manager and referencing them in the template.
- Use separate subnet groups and security groups for different environments (dev, staging, prod).
- Enable CloudFormation drift detection to monitor manual changes.
- Validate templates with tools like `cfn-lint` before deployment.
- Review and customize the schedule expression to fit your migration window.

---

## Outputs
After successful deployment, the following outputs are displayed:

| Output Key              | Description                                |
|------------------------|--------------------------------------------|
| `ReplicationInstanceArn` | ARN of the DMS replication instance       |
| `DMSMigrationTaskArn`    | ARN of the DMS migration task              |

---


---

## Support
For issues or questions, please open an issue or contact the maintainer.

---

## License


