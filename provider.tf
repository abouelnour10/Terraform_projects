terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.62"
    }
  }
}
provider "aws" {
  region     = "us-east-1"
  access_key = "${{ secrets.access_key }}"
  secret_key = "${{ secrets.secret_key }}"
}