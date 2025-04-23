#!/bin/bash

set -euo pipefail

# Default AWS region
AWS_REGION="us-west-1"
AWS_PROFILE="default"
TEMPLATE_FILE="dms-creation.yml"
LOG_FILE="describe_stack_output.log"

usage() {
  cat <<EOF
Usage: $0 -n StackName -s SourceDBPassword -t TargetDBPassword -u SourceUsername -v TargetUsername -a SourceServerName -b TargetServerName -i VpcID -j SubnetIds [-r AWS_REGION] [-p AWS_PROFILE]

Required parameters:
  -n StackName           : Name of the CloudFormation stack
  -s SourceDBPassword    : Password for source RDS PostgreSQL database
  -t TargetDBPassword    : Password for target RDS PostgreSQL database
  -u SourceUsername      : Username for source database
  -v TargetUsername      : Username for target database
  -a SourceServerName    : Source database server endpoint (DNS or IP)
  -b TargetServerName    : Target database server endpoint (DNS or IP)
  -i VpcID               : VPC ID where DMS resources will be deployed
  -j SubnetIds           : Comma-separated list of subnet IDs (e.g. subnet-1234,subnet-5678)

Optional parameters:
  -r AWS_REGION          : AWS region (default: ap-southeast-2)
  -p AWS_PROFILE         : AWS CLI profile (default: default)

Example:
  $0 -n my-dms-stack -s SrcPass123 -t TgtPass123 -u srcuser -v tgtuser -a src.example.com -b tgt.example.com -i vpc-0abcd1234 -j subnet-1111,subnet-2222 -r us-west-2 -p myprofile
EOF
  exit 1
}

# Parse parameters
while getopts ":n:s:t:u:v:a:b:i:j:r:p:h" opt; do
  case $opt in
    n) STACK_NAME="$OPTARG" ;;
    s) SOURCE_DB_PASSWORD="$OPTARG" ;;
    t) TARGET_DB_PASSWORD="$OPTARG" ;;
    u) SOURCE_USERNAME="$OPTARG" ;;
    v) TARGET_USERNAME="$OPTARG" ;;
    a) SOURCE_SERVER_NAME="$OPTARG" ;;
    b) TARGET_SERVER_NAME="$OPTARG" ;;
    i) VPC_ID="$OPTARG" ;;
    j) SUBNET_IDS="$OPTARG" ;;
    r) AWS_REGION="$OPTARG" ;;
    p) AWS_PROFILE="$OPTARG" ;;
    h) usage ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Check required parameters
if [ -z "${STACK_NAME:-}" ] || [ -z "${SOURCE_DB_PASSWORD:-}" ] || [ -z "${TARGET_DB_PASSWORD:-}" ] || \
   [ -z "${SOURCE_USERNAME:-}" ] || [ -z "${TARGET_USERNAME:-}" ] || [ -z "${SOURCE_SERVER_NAME:-}" ] || \
   [ -z "${TARGET_SERVER_NAME:-}" ] || [ -z "${VPC_ID:-}" ] || [ -z "${SUBNET_IDS:-}" ]; then
  echo "Error: Missing required parameters."
  usage
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: CloudFormation template file '$TEMPLATE_FILE' not found."
  exit 1
fi

# Validate CloudFormation template
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://"${TEMPLATE_FILE}" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" >/dev/null

echo "Template validation successful."

# Convert comma-separated subnet IDs to CloudFormation list format
# CloudFormation expects: SubnetIds: [subnet-1234, subnet-5678]
# The CLI parameter-overrides expects space separated list
IFS=',' read -r -a SUBNET_ARRAY <<< "$SUBNET_IDS"
SUBNET_IDS_CFN=""
for subnet in "${SUBNET_ARRAY[@]}"; do
  SUBNET_IDS_CFN+=" $subnet"
done
SUBNET_IDS_CFN="${SUBNET_IDS_CFN#" "}"  # trim leading space

stack_exists() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1
}

if stack_exists; then
  echo "Stack '$STACK_NAME' exists."
  read -p "Do you want to update the stack '$STACK_NAME'? Type 'yes' to confirm: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Stack update cancelled."
    exit 0
  fi

  echo "Updating CloudFormation stack '$STACK_NAME'..."
  aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
      ReplicationInstanceClass=dms.r6.medium \
      TargetDBPassword="$TARGET_DB_PASSWORD" \
      SourceDBPassword="$SOURCE_DB_PASSWORD" \
      SubnetIds="$SUBNET_IDS_CFN" \
      VpcID="$VPC_ID" \
      source-username="$SOURCE_USERNAME" \
      target-username="$TARGET_USERNAME" \
      Source_Server_Name="$SOURCE_SERVER_NAME" \
      Target_Server_Name="$TARGET_SERVER_NAME"

  echo "Stack update initiated. Waiting for completion..."
  aws cloudformation wait stack-update-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE"

  echo "Stack '$STACK_NAME' updated successfully."

else
  echo "Stack '$STACK_NAME' does not exist. Creating stack..."

  aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
      ReplicationInstanceClass=dms.r6.medium \
      TargetDBPassword="$TARGET_DB_PASSWORD" \
      SourceDBPassword="$SOURCE_DB_PASSWORD" \
      SubnetIds="$SUBNET_IDS_CFN" \
      VpcID="$VPC_ID" \
      source-username="$SOURCE_USERNAME" \
      target-username="$TARGET_USERNAME" \
      Source_Server_Name="$SOURCE_SERVER_NAME" \
      Target_Server_Name="$TARGET_SERVER_NAME"

  echo "Stack creation initiated. Waiting for completion..."
  aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE"

  echo "Stack '$STACK_NAME' created successfully."
fi

# Fetch and display stack outputs
echo "Fetching stack outputs..."
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --query "Stacks[0].Outputs" > "$LOG_FILE"

if [ -s "$LOG_FILE" ]; then
  echo "Stack Outputs:"
  jq -r '.[] | "\(.OutputKey): \(.OutputValue)"' "$LOG_FILE"
else
  echo "No outputs found."
fi

rm -f "$LOG_FILE"
