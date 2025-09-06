terraform {
  backend "s3" {
    bucket         = "aiml-summarization-455921291596-eu-west-1"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "aiml-tf-locks-prod"  # <-- add this
    encrypt        = true
  }
}
