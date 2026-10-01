# Terraform AWS Infrastructure

## Project Overview

This project demonstrates how to provision and manage AWS infrastructure using **Terraform Infrastructure as Code (IaC)**.

The infrastructure is deployed in AWS `ap-south-1` (Mumbai) and includes:

- Custom VPC
- Public subnet
- Internet Gateway
- Public route table
- Security group
- EC2 web server
- Amazon S3 remote Terraform state backend
- S3 state versioning
- IAM-controlled S3 access

The project also demonstrates migration from **local Terraform state to remote Terraform state stored in Amazon S3**.

---

# Project Goals

The main objectives of this project were to learn and practice:

- Terraform Infrastructure as Code
- AWS infrastructure provisioning with Terraform
- Terraform providers
- Terraform resources
- Terraform data sources
- Terraform variables
- Terraform outputs
- Terraform state management
- Local-to-remote state migration
- Remote Terraform state using Amazon S3
- S3 bucket versioning
- IAM permissions
- Terraform planning and validation
- AWS CLI
- Git and GitHub
- SSH authentication with GitHub
- Infrastructure verification
- Infrastructure troubleshooting

---

# Architecture

```text
                         AWS Account
                              |
                              v
                    +-------------------+
                    |       VPC         |
                    |   10.10.0.0/16    |
                    +-------------------+
                              |
                              v
                    +-------------------+
                    |   Public Subnet   |
                    |   10.10.1.0/24    |
                    |    ap-south-1b     |
                    +-------------------+
                              |
                    +---------+---------+
                    |                   |
                    v                   v
             Internet Gateway      Route Table
                                      |
                                      v
                                0.0.0.0/0
                                      |
                                      v
                                   Internet
                                      |
                                      v
                             +----------------+
                             | EC2 Web Server |
                             |    t3.micro    |
                             +----------------+


                    Terraform Remote State
                              |
                              v
                    +----------------------+
                    |     Amazon S3         |
                    |                        |
                    | praful-terraform-     |
                    | project4-s3-2026      |
                    |                        |
                    | project4/             |
                    | terraform.tfstate     |
                    |                        |
                    | Versioning: Enabled   |
                    +----------------------+
```

---

# AWS Resources

## VPC

- CIDR: `10.10.0.0/16`
- Name: `terraform-project4-vpc`

## Public Subnet

- CIDR: `10.10.1.0/24`
- Availability Zone: `ap-south-1b`
- Public IP assignment enabled

## Internet Gateway

Provides internet connectivity for the public subnet.

## Route Table

The public route table contains:

```text
0.0.0.0/0 -> Internet Gateway
```

## Security Group

The EC2 security group allows:

| Protocol | Port | Source | Purpose |
|---|---:|---|---|
| TCP | 22 | Configured SSH CIDR | SSH access |
| TCP | 80 | `0.0.0.0/0` | HTTP access |
| All | All | `0.0.0.0/0` | Outbound traffic |

## EC2 Instance

- Instance type: `t3.micro`
- Amazon Linux
- Public IP enabled
- Existing AWS key pair
- User-data script used for initialization
- AMI supplied through the `ami_id` variable

---

# Project Structure

```text
04-terraform-aws-infrastructure/
│
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── user_data.sh
└── README.md
```

Terraform-generated files such as `.terraform/` and Terraform state files are intentionally excluded from Git.

---

# Terraform Provider

The project uses the official HashiCorp AWS provider:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

The AWS region is configured through a Terraform variable:

```hcl
provider "aws" {
  region = var.aws_region
}
```

---

# Terraform Data Sources

The project uses Terraform data sources to retrieve existing AWS information.

## Amazon Linux AMI

Terraform can query Amazon-owned Amazon Linux AMIs:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
```

The EC2 resource was later changed to use an explicitly supplied `ami_id` variable.

This was done after observing that dynamically selecting the latest AMI could cause Terraform to replace the EC2 instance when a newer AMI became available.

---

## EC2 Key Pair

An existing AWS key pair is retrieved using:

```hcl
data "aws_key_pair" "ec2" {
  key_name = "devops-docker-lab-mumbai"
}
```

---

# Terraform Variables

The project uses variables instead of unnecessarily hardcoding infrastructure configuration.

The main variables are:

```text
aws_region
instance_type
vpc_cidr
public_subnet_cidr
availability_zone
ssh_allowed_cidr
ami_id
```

Example:

```hcl
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
```

The environment-specific values are supplied through `terraform.tfvars`.

Example:

```hcl
aws_region         = "ap-south-1"
instance_type      = "t3.micro"
vpc_cidr           = "10.10.0.0/16"
public_subnet_cidr = "10.10.1.0/24"
availability_zone  = "ap-south-1b"
ssh_allowed_cidr   = "YOUR_IP/32"
ami_id             = "YOUR_AMI_ID"
```

`terraform.tfvars` is intentionally excluded from Git through `.gitignore`.

---

# Terraform Outputs

The project exposes useful infrastructure information through Terraform outputs:

```text
vpc_id
public_subnet_id
security_group_id
instance_id
instance_private_ip
instance_public_ip
```

Display them with:

```bash
terraform output
```

---

# Remote Terraform State

One of the most important parts of this project is the migration from **local Terraform state to remote state stored in Amazon S3**.

Initially, Terraform maintained local state files:

```text
terraform.tfstate
terraform.tfstate.backup
```

A backup was created before migration:

```bash
terraform state pull > /tmp/project4-state-backup.tfstate
```

The project was then configured to use Amazon S3 as the Terraform backend.

---

# S3 Backend Configuration

The Terraform backend is configured in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "praful-terraform-project4-s3-2026"
    key    = "project4/terraform.tfstate"
    region = "ap-south-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

The remote Terraform state is stored at:

```text
S3 Bucket:
praful-terraform-project4-s3-2026

State Key:
project4/terraform.tfstate

Region:
ap-south-1
```

---

# Local State to S3 Migration

Before migration, Terraform state was stored locally.

A backup was created:

```bash
terraform state pull > /tmp/project4-state-backup.tfstate
```

The S3 backend was then initialized:

```bash
terraform init
```

Terraform detected the existing local state and asked:

```text
Do you want to copy existing state to the new backend?
```

The answer was:

```text
yes
```

Terraform then successfully configured the S3 backend and migrated the existing state.

---

# Verifying Remote State

The Terraform-managed resources were verified using:

```bash
terraform state list
```

The state contained:

```text
data.aws_ami.amazon_linux
data.aws_key_pair.ec2
aws_instance.web
aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public
aws_security_group.web
aws_subnet.public
aws_vpc.main
```

The remote S3 state object was verified using:

```bash
aws s3 ls s3://praful-terraform-project4-s3-2026/project4/
```

The object was present as:

```text
terraform.tfstate
```

---

# S3 Versioning

S3 versioning was enabled on the Terraform state bucket.

It was verified using:

```bash
aws s3api get-bucket-versioning \
  --bucket praful-terraform-project4-s3-2026
```

The result was:

```json
{
    "Status": "Enabled"
}
```

## Why S3 Versioning Matters

Terraform state contains important information about infrastructure managed by Terraform.

If the state object is accidentally modified or overwritten, S3 versioning provides historical versions that can assist with recovery and investigation.

Therefore, versioning adds an additional layer of protection to the remote Terraform state.

---

# IAM Permissions

Access to the Terraform state bucket is controlled through AWS IAM.

The IAM permissions required for working with the state bucket include:

```text
s3:ListBucket
s3:GetBucketLocation
s3:GetBucketVersioning
s3:ListBucketVersions
```

The bucket resource is:

```text
arn:aws:s3:::praful-terraform-project4-s3-2026
```

The IAM policy was attached through the IAM group used by the `Praful` IAM user.

The permission relationship is:

```text
IAM User
   |
   v
IAM Group
   |
   v
IAM Policy
   |
   v
S3 Bucket Permissions
```

This demonstrated how AWS IAM controls access to S3 resources.

---

# AWS Identity Verification

The authenticated AWS identity was verified with:

```bash
aws sts get-caller-identity
```

The CLI authenticated as the `Praful` IAM user.

---

# S3 Access Verification

After the required IAM permissions were configured, S3 access was verified.

List buckets:

```bash
aws s3 ls
```

The project bucket was visible:

```text
praful-terraform-project4-s3-2026
```

The bucket contents were checked:

```bash
aws s3 ls s3://praful-terraform-project4-s3-2026
```

---

# S3 Upload and Download Test

A temporary test file was created:

```bash
echo "Hello from Terraform Project 4" > test.txt
```

The file was uploaded:

```bash
aws s3 cp test.txt s3://praful-terraform-project4-s3-2026/
```

The upload was verified:

```bash
aws s3 ls s3://praful-terraform-project4-s3-2026
```

The file was downloaded:

```bash
aws s3 cp \
  s3://praful-terraform-project4-s3-2026/test.txt \
  downloaded-test.txt
```

The downloaded file was verified:

```bash
cat downloaded-test.txt
```

Output:

```text
Hello from Terraform Project 4
```

The temporary test files were removed afterward.

---

# Terraform Validation

The Terraform configuration was formatted using:

```bash
terraform fmt
```

The configuration was validated using:

```bash
terraform validate
```

Result:

```text
Success! The configuration is valid.
```

---

# Terraform Plan

The infrastructure was checked using:

```bash
terraform plan
```

The final result was:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that:

- Terraform can access the remote state.
- Terraform can refresh the AWS infrastructure.
- The AWS resources match the Terraform configuration.
- No unexpected infrastructure changes are currently planned.

---

# AMI Pinning

During the project, the EC2 instance initially used a dynamically selected Amazon Linux AMI.

Terraform detected that the AMI had changed and showed that the EC2 instance would need to be replaced:

```text
-/+ destroy and then create replacement
```

The configuration was changed to explicitly provide the AMI through:

```hcl
ami = var.ami_id
```

This made the EC2 configuration more predictable and prevented an automatic replacement simply because a newer AMI became available.

---

# Git and GitHub

The project is maintained using Git and hosted on GitHub.

Repository:

```text
https://github.com/prafulchouraddi2001-glitch/-04-terraform-aws-infrastructure
```

The repository uses the:

```text
main
```

branch.

Important commits include:

```text
Initial Terraform AWS infrastructure
Pin EC2 AMI for stable infrastructure
Configure S3 backend for Terraform state
```

GitHub SSH authentication was configured so the repository could be pushed without using a GitHub Personal Access Token.

---

# Git Ignore

Terraform state and local Terraform files are excluded from Git.

Important `.gitignore` entries include:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
```

This is important because:

- Terraform state can contain sensitive infrastructure information.
- `terraform.tfvars` may contain environment-specific values or secrets.
- `.terraform/` contains downloaded provider and Terraform working files.

---

# Useful Terraform Commands

## Initialize Terraform

```bash
terraform init
```

## Format Terraform configuration

```bash
terraform fmt
```

## Validate configuration

```bash
terraform validate
```

## Create an execution plan

```bash
terraform plan
```

## Apply infrastructure

```bash
terraform apply
```

## Display Terraform outputs

```bash
terraform output
```

## List resources tracked by Terraform

```bash
terraform state list
```

## Pull the current state

```bash
terraform state pull
```

## Refresh infrastructure information

```bash
terraform plan -refresh-only
```

---

# Key Concepts Learned

## 1. Infrastructure as Code

Infrastructure can be described and managed through code instead of manually creating every AWS resource through the AWS Console.

---

## 2. Declarative Infrastructure

Terraform describes the desired infrastructure state.

Terraform determines the actions required to make the real infrastructure match that desired configuration.

---

## 3. Terraform State

Terraform state maintains the relationship between Terraform configuration and real infrastructure.

Terraform uses state to determine which resources it manages and what changes are required.

---

## 4. Remote State

Instead of keeping Terraform state only on one developer's computer, Terraform can store state remotely.

This project uses Amazon S3 as the remote Terraform backend.

---

## 5. State Migration

Existing local Terraform state can be migrated to a new backend using:

```bash
terraform init
```

Terraform can detect the existing state and ask whether it should be copied to the new backend.

---

## 6. S3 Versioning

S3 versioning provides historical versions of the Terraform state object.

This provides an additional recovery mechanism if the state object is accidentally modified or overwritten.

---

## 7. IAM

AWS IAM controls which identities can perform actions on AWS resources.

This project demonstrated IAM-controlled access to the Terraform state bucket.

---

## 8. Data Sources

Terraform data sources allow configuration to query information that already exists in AWS.

Examples:

```text
aws_ami
aws_key_pair
```

---

## 9. Variables

Terraform variables make configurations more reusable and allow environment-specific values to be separated from infrastructure definitions.

---

## 10. Outputs

Terraform outputs expose useful infrastructure information such as:

```text
VPC ID
Subnet ID
Security Group ID
EC2 Instance ID
Private IP
Public IP
```

---

## 11. Terraform Plan

`terraform plan` allows infrastructure changes to be reviewed before applying them.

This is an important safety mechanism in infrastructure automation.

---

## 12. Infrastructure Drift

Terraform refreshes information about real AWS resources during planning.

This allows Terraform to identify differences between:

```text
Terraform Configuration
        |
        v
Terraform State
        |
        v
Actual AWS Infrastructure
```

---

# Troubleshooting Experience

During this project, several real-world issues were encountered and resolved.

## IAM AccessDenied Errors

Initially, AWS CLI operations such as:

```bash
aws s3 ls
```

returned:

```text
AccessDenied
```

The issue was caused by missing IAM permissions.

The required S3 permissions were added to the IAM policy and the policy was attached through the IAM group used by the `Praful` user.

After the permissions were corrected:

```bash
aws s3 ls
```

successfully displayed the project bucket.

---

## Terraform AMI Replacement

The initial EC2 configuration dynamically selected the most recent Amazon Linux AMI.

When the AMI changed, Terraform detected that the EC2 instance would need replacement.

The configuration was changed to explicitly provide the AMI ID through:

```hcl
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
```

and:

```hcl
ami = var.ami_id
```

This provided more predictable infrastructure behavior.

---

## AWS CLI `list-object-versions` Issue

The command:

```bash
aws s3api list-object-versions
```

returned:

```text
badly formed help string
```

even though other AWS CLI commands worked correctly.

The issue was investigated as an AWS CLI/WSL environment issue rather than changing the Terraform or S3 configuration unnecessarily.

S3 versioning itself was independently verified using:

```bash
aws s3api get-bucket-versioning \
  --bucket praful-terraform-project4-s3-2026
```

which returned:

```text
Status: Enabled
```

---

# Project Verification Checklist

The following items were successfully verified:

- [x] Terraform installed and working
- [x] AWS CLI installed and authenticated
- [x] AWS identity verified with STS
- [x] Terraform AWS provider initialized
- [x] VPC created and managed
- [x] Public subnet created and managed
- [x] Internet Gateway configured
- [x] Route table configured
- [x] Security group configured
- [x] EC2 instance managed by Terraform
- [x] Terraform variables implemented
- [x] Terraform outputs implemented
- [x] Terraform formatting completed
- [x] Terraform validation successful
- [x] Terraform plan successful
- [x] S3 bucket created
- [x] S3 access verified
- [x] S3 upload/download tested
- [x] S3 versioning enabled
- [x] IAM permissions configured
- [x] Existing local Terraform state backed up
- [x] Terraform state migrated to S3
- [x] Remote state verified
- [x] Git repository initialized
- [x] GitHub repository created
- [x] GitHub SSH authentication configured
- [x] Project pushed to GitHub
- [x] Working tree clean
- [x] Final `terraform plan` returned no changes

---

# Skills Demonstrated

```text
Terraform
AWS
Amazon EC2
Amazon VPC
Amazon S3
AWS IAM
Terraform State
Terraform Remote Backend
S3 Versioning
Infrastructure as Code
Terraform Variables
Terraform Outputs
Terraform Data Sources
Git
GitHub
AWS CLI
Linux / WSL
Infrastructure Troubleshooting
```

---

# Project Status

**Status: COMPLETED**

This project successfully demonstrates provisioning AWS infrastructure with Terraform and managing Terraform state remotely using Amazon S3 with versioning and IAM-controlled access.

The project also demonstrates practical DevOps workflows including infrastructure validation, planning, state management, AWS CLI troubleshooting, Git version control, and GitHub SSH authentication.
## Project Overview

This project demonstrates how to provision and manage AWS infrastructure using **Terraform**.

The infrastructure is deployed in AWS `ap-south-1` (Mumbai) and includes a custom VPC, public subnet, Internet Gateway, route table, security group, and an EC2 web server.

The project also demonstrates an important production-style Terraform practice: using an **Amazon S3 bucket as a remote Terraform state backend**, with **S3 versioning enabled** and IAM-controlled access.

---

## Project Goals

The main objectives of this project were to learn and practice:

- Terraform infrastructure as code (IaC)
- AWS infrastructure provisioning with Terraform
- Terraform providers
- Terraform resources and data sources
- Terraform variables
- Terraform outputs
- Terraform state management
- Terraform state migration
- S3 bucket versioning
- IAM permissions for Terraform state access
- Terraform planning and validation
- Git and GitHub version control
- Infrastructure verification and troubleshooting

---

## Architecture

The project creates the following AWS infrastructure:

```text
                         AWS Account
                              |
                              v
                       +--------------+
                       |     VPC      |
                       | 10.10.0.0/16 |
                       +--------------+
                              |
                              v
                    +-------------------+
                    |   Public Subnet   |
                    |  10.10.1.0/24     |
                    |  ap-south-1b      |
                    +-------------------+
                              |
                    +---------+---------+
                    |                   |
                    v                   v
             Internet Gateway     Route Table
                                      |
                                      v
                              0.0.0.0/0
                                      |
                                      v
                               Internet
                                      |
                                      v
                              +---------------+
                              | EC2 Web Server|
                              |   t3.micro    |
                              +---------------+

Terraform State
      |
      v
+--------------------------------------+
| Amazon S3                            |
| praful-terraform-project4-s3-2026   |
|                                      |
| project4/terraform.tfstate           |
|                                      |
| Versioning: Enabled                  |
+--------------------------------------+
```

---

## AWS Resources

The following infrastructure is managed by Terraform:

### VPC

- CIDR: `10.10.0.0/16`
- Name: `terraform-project4-vpc`

### Public Subnet

- CIDR: `10.10.1.0/24`
- Availability Zone: `ap-south-1b`
- Public IP assignment enabled

### Internet Gateway

Provides internet connectivity for the public subnet.

### Route Table

The public route table contains:

```text
0.0.0.0/0 -> Internet Gateway
```

### Security Group

The EC2 security group allows:

| Protocol | Port | Source | Purpose |
|---|---:|---|---|
| TCP | 22 | Configured SSH CIDR | SSH access |
| TCP | 80 | `0.0.0.0/0` | HTTP access |
| All | All | `0.0.0.0/0` | Outbound traffic |

### EC2 Instance

- Instance type: `t3.micro`
- Amazon Linux AMI
- Public IP enabled
- SSH key pair configured
- User-data script used for instance initialization

---

## Terraform Project Structure

```text
04-terraform-aws-infrastructure/
│
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── user_data.sh
└── README.md
```

Terraform-generated files such as `.terraform/` and local state files are intentionally excluded from Git.

---

## Terraform Configuration

### Provider

The project uses the official AWS provider:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

---

## Terraform Data Sources

The project uses data sources to retrieve existing AWS information.

### Amazon Linux AMI

Terraform queries Amazon-owned AMIs:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
```

### EC2 Key Pair

The existing AWS key pair is retrieved using:

```hcl
data "aws_key_pair" "ec2" {
  key_name = "devops-docker-lab-mumbai"
}
```

---

## Terraform Variables

The project uses variables instead of hardcoding infrastructure configuration throughout the Terraform resources.

Examples include:

```text
aws_region
instance_type
vpc_cidr
public_subnet_cidr
availability_zone
ssh_allowed_cidr
ami_id
```

The EC2 AMI is explicitly provided through `ami_id`.

This allows the infrastructure configuration to remain reusable while keeping environment-specific values separate.

---

## Terraform Outputs

The project exposes useful infrastructure information through Terraform outputs:

```text
vpc_id
public_subnet_id
security_group_id
instance_id
instance_private_ip
instance_public_ip
```

These can be displayed using:

```bash
terraform output
```

---

# Remote Terraform State

One of the most important parts of this project is the migration from local Terraform state to a remote S3 backend.

Initially, Terraform stored state locally:

```text
terraform.tfstate
terraform.tfstate.backup
```

The state was then migrated to Amazon S3.

---

## S3 Backend Configuration

The Terraform backend is configured in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "praful-terraform-project4-s3-2026"
    key    = "project4/terraform.tfstate"
    region = "ap-south-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

The remote state is stored at:

```text
S3 Bucket:
praful-terraform-project4-s3-2026

State Key:
project4/terraform.tfstate

Region:
ap-south-1
```

---

## State Migration

Before migration, Terraform state was stored locally.

A backup was created using:

```bash
terraform state pull > /tmp/project4-state-backup.tfstate
```

The S3 backend was then initialized:

```bash
terraform init
```

Terraform detected the existing local state and asked:

```text
Do you want to copy existing state to the new backend?
```

The answer was:

```text
yes
```

Terraform then successfully migrated the existing state to the S3 backend.

---

## Verifying Remote State

Terraform state resources were verified with:

```bash
terraform state list
```

The state contained:

```text
data.aws_ami.amazon_linux
data.aws_key_pair.ec2
aws_instance.web
aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public
aws_security_group.web
aws_subnet.public
aws_vpc.main
```

The remote state object was also verified in S3:

```bash
aws s3 ls s3://praful-terraform-project4-s3-2026/project4/
```

The Terraform state file was present as:

```text
terraform.tfstate
```

---

# S3 Versioning

Versioning was enabled on the Terraform state bucket.

It was verified using:

```bash
aws s3api get-bucket-versioning \
  --bucket praful-terraform-project4-s3-2026
```

The result was:

```json
{
    "Status": "Enabled"
}
```

### Why S3 Versioning Matters

Terraform state contains important information about the infrastructure Terraform manages.

If the state file is accidentally overwritten or changed, versioning provides previous object versions that can help with recovery and investigation.

Therefore, S3 versioning is an important protection for a remote Terraform state bucket.

---

# IAM Permissions

Access to the Terraform state bucket is controlled through IAM.

The IAM policy used for the project includes permissions required to work with the S3 state bucket.

Important permissions include:

```text
s3:ListBucket
s3:GetBucketLocation
s3:GetBucketVersioning
s3:ListBucketVersions
```

The bucket resource is:

```text
arn:aws:s3:::praful-terraform-project4-s3-2026
```

The IAM policy was attached to the IAM group used by the `Praful` IAM user.

This demonstrated an important AWS concept:

```text
IAM User
   |
   v
IAM Group
   |
   v
IAM Policy
   |
   v
S3 Bucket Permissions
```

---

# S3 Access Verification

S3 access was tested from the AWS CLI.

First, the authenticated AWS identity was verified:

```bash
aws sts get-caller-identity
```

The AWS CLI was then able to list the bucket:

```bash
aws s3 ls
```

The project bucket was visible:

```text
praful-terraform-project4-s3-2026
```

The bucket contents were checked:

```bash
aws s3 ls s3://praful-terraform-project4-s3-2026
```

---

## S3 Upload and Download Test

A test file was created:

```bash
echo "Hello from Terraform Project 4" > test.txt
```

The file was uploaded:

```bash
aws s3 cp test.txt s3://praful-terraform-project4-s3-2026/
```

The upload was verified:

```bash
aws s3 ls s3://praful-terraform-project4-s3-2026
```

The file was downloaded again:

```bash
aws s3 cp \
  s3://praful-terraform-project4-s3-2026/test.txt \
  downloaded-test.txt
```

The downloaded file was verified:

```bash
cat downloaded-test.txt
```

The result confirmed that the S3 bucket could successfully store and retrieve objects.

The temporary test files were removed from the project directory afterward.

---

# Terraform Validation

The Terraform configuration was validated using:

```bash
terraform validate
```

Result:

```text
Success! The configuration is valid.
```

Terraform formatting was also applied using:

```bash
terraform fmt
```

---

# Terraform Plan

The infrastructure was checked using:

```bash
terraform plan
```

The final result was:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that:

- Terraform can access the remote state.
- Terraform can refresh the AWS infrastructure.
- The AWS resources match the configuration.
- No unexpected infrastructure changes are currently planned.

---

# Git and GitHub

The project is maintained using Git and hosted on GitHub.

Repository:

```text
https://github.com/prafulchouraddi2001-glitch/-04-terraform-aws-infrastructure
```

Git was configured with the project author's identity and the project was committed using meaningful commit messages.

Important commits include:

```text
Initial Terraform AWS infrastructure
Pin EC2 AMI for stable infrastructure
Configure S3 backend for Terraform state
```

The repository uses the `main` branch.

SSH authentication was configured for GitHub so that the repository could be pushed without using a Personal Access Token.

---

# Git Ignore

Terraform state and other local Terraform files are excluded from Git using `.gitignore`.

Examples include:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
```

This is important because Terraform state can contain sensitive infrastructure information, and environment-specific variable files may contain secrets or other values that should not be committed.

---

# Useful Terraform Commands

Initialize Terraform:

```bash
terraform init
```

Format Terraform configuration:

```bash
terraform fmt
```

Validate configuration:

```bash
terraform validate
```

Create an execution plan:

```bash
terraform plan
```

Apply infrastructure:

```bash
terraform apply
```

Display Terraform outputs:

```bash
terraform output
```

List resources tracked by Terraform:

```bash
terraform state list
```

Pull the current state:

```bash
terraform state pull
```

Refresh infrastructure information:

```bash
terraform plan -refresh-only
```

---

# Key Concepts Learned

## 1. Infrastructure as Code

Infrastructure can be described as code rather than manually creating every AWS resource through the console.

---

## 2. Declarative Infrastructure

Terraform describes the desired infrastructure state.

Terraform then determines the actions necessary to make the real AWS environment match that configuration.

---

## 3. Terraform State

Terraform state maintains the relationship between Terraform configuration and real infrastructure.

Without reliable state management, Terraform cannot safely determine which resources it manages.

---

## 4. Remote State

Instead of keeping state only on one developer's computer, Terraform can store state remotely.

This project uses Amazon S3 as the remote backend.

---

## 5. State Migration

Existing local Terraform state can be migrated to a new backend using:

```bash
terraform init
```

Terraform can detect the existing state and migrate it to the new backend.

---

## 6. S3 Versioning

S3 versioning provides historical versions of the Terraform state object.

This provides an additional recovery mechanism if the state object is accidentally modified or overwritten.

---

## 7. IAM

AWS IAM controls which identities can perform actions on AWS resources.

The project demonstrated how IAM permissions can control access to the Terraform state bucket.

---

## 8. Data Sources

Terraform data sources allow configuration to query information that already exists in AWS.

Examples in this project include:

```text
aws_ami
aws_key_pair
```

---

## 9. Variables

Terraform variables make configurations more reusable and prevent infrastructure configuration from being unnecessarily hardcoded.

---

## 10. Outputs

Terraform outputs expose useful values such as:

```text
VPC ID
Subnet ID
Security Group ID
EC2 Instance ID
Private IP
Public IP
```

---

## 11. Terraform Plan

`terraform plan` allows infrastructure changes to be reviewed before applying them.

This is an important safety mechanism in infrastructure automation.

---

## 12. Infrastructure Drift

Terraform refreshes information about real AWS resources during planning.

This allows Terraform to detect differences between the configuration, state, and actual infrastructure.

---

# Troubleshooting Experience

During this project, several real-world issues were encountered and resolved.

### IAM AccessDenied Errors

Initially, AWS CLI operations such as:

```bash
aws s3 ls
```

returned:

```text
AccessDenied
```

The issue was traced to missing IAM permissions.

The appropriate S3 permissions were added to the IAM policy and attached to the IAM group used by the `Praful` user.

---

### Terraform AMI Changes

The initial configuration dynamically selected the most recent Amazon Linux AMI.

When the AMI changed, Terraform detected that the EC2 instance would need replacement.

The project was changed to explicitly provide the AMI ID through the `ami_id` variable.

This provided more predictable infrastructure behavior.

---

### AWS CLI `list-object-versions` Issue

The command:

```bash
aws s3api list-object-versions
```

returned:

```text
badly formed help string
```

even though other AWS CLI commands worked.

The issue was investigated as an AWS CLI/WSL environment issue rather than continuing to modify the Terraform or S3 configuration.

S3 versioning itself was independently verified using:

```bash
aws s3api get-bucket-versioning
```

which returned:

```text
Status: Enabled
```

---

# Project Verification Checklist

The following items were successfully verified:

- [x] Terraform installed and working
- [x] AWS CLI installed and authenticated
- [x] AWS identity verified with STS
- [x] Terraform AWS provider initialized
- [x] VPC created and managed
- [x] Public subnet created and managed
- [x] Internet Gateway configured
- [x] Route table configured
- [x] Security group configured
- [x] EC2 instance managed by Terraform
- [x] Terraform variables implemented
- [x] Terraform outputs implemented
- [x] Terraform validation successful
- [x] Terraform plan successful
- [x] S3 bucket created
- [x] S3 access verified
- [x] S3 upload/download tested
- [x] S3 versioning enabled
- [x] IAM permissions configured
- [x] Existing local Terraform state backed up
- [x] Terraform state migrated to S3
- [x] Remote state verified
- [x] Git repository initialized
- [x] GitHub repository created
- [x] GitHub SSH authentication configured
- [x] Project pushed to GitHub
- [x] Working tree clean
- [x] Final `terraform plan` returned no changes

---

# Skills Demonstrated

This project demonstrates hands-on experience with:

```text
Terraform
AWS
Amazon EC2
Amazon VPC
Amazon S3
AWS IAM
Terraform State
Terraform Remote Backend
S3 Versioning
Infrastructure as Code
Terraform Variables
Terraform Outputs
Terraform Data Sources
Git
GitHub
AWS CLI
Linux / WSL
Infrastructure Troubleshooting
```

---

# Project Status

**Status: COMPLETED**

The project successfully demonstrates provisioning AWS infrastructure with Terraform and managing Terraform state remotely using Amazon S3 with versioning and IAM-controlled access.
