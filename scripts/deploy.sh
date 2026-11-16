#!/usr/bin/env bash
# Deploy the stack, locking bastion SSH to your current public IP.
# Usage: ./scripts/deploy.sh [stack-name] [region] [Param=Value ...]
#   e.g. ./scripts/deploy.sh shopsecure eu-west-2 KeyName=my-key
set -euo pipefail
STACK="${1:-shopsecure}"
REGION="${2:-$(aws configure get region)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
shift $(( $# < 2 ? $# : 2 ))

MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')/32"
echo "==> Bastion SSH will be allowed from $MY_IP only"

echo "==> Deploying $STACK to $REGION (RDS takes ~10 minutes)"
aws cloudformation deploy --region "$REGION" --stack-name "$STACK" \
  --template-file "$ROOT/infrastructure/template.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides AllowedSshCidr="$MY_IP" "$@"

aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].Outputs" --output table
