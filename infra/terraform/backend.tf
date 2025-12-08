terraform {
  # Remote backend is configured via -backend-config in CI/CD (per environment)
  # Required values provided at init time:
  #   bucket     = <S3 bucket>
  #   key        = <per-env state key>
  #   region     = <AWS region>
  #   dynamodb_table = <DynamoDB lock table>
  #   encrypt    = true
  backend "s3" {
    # Backend configuration is provided via -backend-config flags during terraform init
    # This allows per-environment state management
  }
}

