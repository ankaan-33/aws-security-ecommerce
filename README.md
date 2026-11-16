# ShopSecure – Secure E-Commerce Deployment on AWS

**AWS Well-Architected Framework: Security Pillar**

Many e-commerce businesses rush to market, and rapid growth then exposes gaps in their security. This project takes a vulnerable, publicly exposed setup and rebuilds it as a layered, production-style architecture where only the front door faces the internet.

```
 Users ──HTTPS──▶ CloudFront ──(secret origin header)──▶ AWS WAF ──▶ ALB      ← public subnets
                                                                    │
 Admin ──SSH (one IP)──▶ Bastion host ──SSH──┐                      │ HTTP
                                             ▼                      ▼
                                    EC2 app server (no public IP)              ← private app subnets
                                       │            │      └─▶ NAT gateway (outbound updates only)
                         S3 gateway endpoint      MySQL
                                       ▼            ▼
                       S3 assets bucket       RDS MySQL (encrypted)            ← private data subnets
                 (private, TLS-only, versioned)   (no internet route at all)
```

## Security controls, layer by layer

| Layer | Control |
|---|---|
| **Edge** | CloudFront redirects HTTP to HTTPS. The ALB rejects any request missing CloudFront's secret header, so the HTTPS front door can't be bypassed. |
| **Application firewall** | AWS WAF has AWS managed rules (common exploits, SQL injection, known bad inputs), a custom rule blocking `/admin`, and a per-client rate limit. |
| **Network** | Three tiers across two AZs. The app server has no public IP. The database subnets have no route to the internet. |
| **Access** | Security groups are chained (ALB → app → DB), and SSH reaches only the bastion, from one IP. Both instances support Session Manager, so you don't need SSH at all. |
| **Identity** | Least-privilege instance role: read one S3 bucket and one database secret, nothing more. |
| **Data** | RDS, S3 and EBS are encrypted at rest. The S3 bucket policy refuses non-TLS requests and all public access is blocked. The DB password is generated into Secrets Manager. |
| **Host** | IMDSv2 is required, and the Apache version banner is hidden. |

## What's in this repo

| Path | What it is |
|---|---|
| `infrastructure/template.yaml` | CloudFormation for the full architecture |
| `app/index.html` | Demo storefront page |
| `scripts/deploy.sh` | Deploys the stack, with SSH automatically limited to your current IP |
| `scripts/security-tests.sh` | curl tests showing each control blocks what it should |

## Deploy

**You'll need:** the AWS CLI, logged in. An EC2 key pair is optional and only needed for SSH through the bastion.

```bash
./scripts/deploy.sh shopsecure <region>                    # Session Manager only
./scripts/deploy.sh shopsecure <region> KeyName=<your-key> # also enable SSH via the bastion
./scripts/security-tests.sh shopsecure <region>
```

To SSH to the private app server through the bastion, use the `SshViaBastion` output (`ssh -J …`).

## Improvements on my first console build

I first built this by hand in the AWS console. Writing it as code let me go further in a few places:

- **CloudFront can't be bypassed.** In the console build, the ALB was still reachable directly over plain HTTP.
- **WAF has more protection:** a rate limit based on the real client IP (from `X-Forwarded-For`) and a known-bad-inputs rule set, on top of the SQL injection and `/admin` rules.
- **No stored secrets.** The database password lives in Secrets Manager, not in a parameter or in code.
- **An S3 gateway endpoint** keeps S3 traffic on the AWS network.

## Cost and clean-up

This stack is **not** free tier. The NAT gateway (about $1 a day plus data), the ALB, RDS and two instances add up to roughly **$2–3 a day**. Delete it once you've finished:

```bash
aws s3 rm s3://<AssetsBucketName> --recursive   # versioned: also delete old versions in the console
aws cloudformation delete-stack --stack-name shopsecure --region <region>
```

## Next steps

- A custom domain with an ACM certificate, HTTPS from CloudFront to the ALB, and an `https-only` origin policy
- WAF logging to S3 or CloudWatch, plus GuardDuty and Security Hub
- An Auto Scaling group for the app tier (see my [Reliability Pillar project](https://github.com/ankaan-33/aws-reliability-medicarehub))
- RDS IAM authentication and enforced TLS connections
