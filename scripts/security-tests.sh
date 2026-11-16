#!/usr/bin/env bash
# Prove each control works. Usage: ./scripts/security-tests.sh [stack-name] [region]
set -uo pipefail
STACK="${1:-shopsecure}"
REGION="${2:-$(aws configure get region)}"

out() { aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
          --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
STORE=$(out StoreUrl); ALB=$(out DirectAlbUrl); BUCKET=$(out AssetsBucketName)

check() { printf '%-55s expect %-4s got %s\n' "$1" "$2" "$3"; }

check "Store over HTTPS (CloudFront)"            200 "$(curl -s -o /dev/null -w '%{http_code}' "$STORE/")"
check "HTTP redirects to HTTPS"                  301 "$(curl -s -o /dev/null -w '%{http_code}' "${STORE/https/http}/")"
check "ALB directly, bypassing CloudFront"       403 "$(curl -s -o /dev/null -w '%{http_code}' "$ALB/")"
check "WAF: /admin path"                         403 "$(curl -s -o /dev/null -w '%{http_code}' "$STORE/admin")"
check "WAF: SQL injection in query string"       403 "$(curl -s -o /dev/null -w '%{http_code}' "$STORE/?id=1%27%20OR%20%271%27%3D%271")"
check "S3 bucket, anonymous access"              403 "$(curl -s -o /dev/null -w '%{http_code}' "https://$BUCKET.s3.$REGION.amazonaws.com/")"
echo
echo "Also check: the app server has no public IP (EC2 console), and the RDS instance shows"
echo "'Publicly accessible: No' and 'Encryption: Enabled'."
