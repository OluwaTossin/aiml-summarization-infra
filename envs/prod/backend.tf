terraform {
  backend "s3" {
    bucket       = "aiml-summarization-455921291596-eu-west-1"
    key          = "prod/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true # <-- enable S3-native locking
    encrypt      = true
  }
}
