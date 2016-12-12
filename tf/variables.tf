variable "s3prefix" {
  description = "Roadworker files prefix in s3 backup bucket"
}

variable "s3bucketname" {
  description = "Roadworker bucket"
}

variable "region" {
  description = "AWS Region"
}

variable "filename" {
  description = "AWS Region"
  default = "codebuild-project.json"
}

variable "codebuild_image" {
  description = "CodeBuild image to use for creating Lambda function"
}

variable "with_lambda" {
  description = "Build environment with Lambda"
  default = false
}
