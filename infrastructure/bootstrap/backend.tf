terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "olist-terraform-state-f5f7801c2d8371f768e1c491de"
    key          = "olist/bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}