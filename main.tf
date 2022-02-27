terraform {
  backend "s3" {
    bucket = "tfstates-joel"
    key    = "imdb/"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}