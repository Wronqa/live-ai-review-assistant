terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = "eu-north-1" 
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "lara-tfstate-${random_id.suffix.hex}"
  lifecycle { prevent_destroy = true }
  tags = { Project = "lara", Purpose = "terraform-state" }
}

resource "aws_s3_bucket_versioning" "ver" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = "lara-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = { Project = "lara", Purpose = "terraform-locks" }
}

output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
output "lock_table"   { value = aws_dynamodb_table.lock.name }