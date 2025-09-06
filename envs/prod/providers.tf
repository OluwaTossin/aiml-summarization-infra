# Only provider configurations here (no terraform { } block)

provider "aws" {
  region = var.aws_region
  # profile = var.aws_profile  # optional, if you added this variable
}

provider "github" {
  owner = var.github_owner
  # token comes from env var GITHUB_TOKEN; do not hardcode
}
