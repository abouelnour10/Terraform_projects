terraform {
  backend "s3" {
    bucket = "my-terraform-state-buckend-aboelnour"
    key    = "terraform/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}