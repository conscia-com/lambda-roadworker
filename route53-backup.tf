variable "s3prefix" {
  description = "Roadworker files prefix in s3 backup bucket (defaults to roadworker/)"
  default = "roadworker/"
}

variable "s3bucketname" {
  description = "Roadworker files prefix in s3 backup bucket (defaults to roadworker/)"
  default = "hennings-roadworker-backup-bucket"
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_iam_role" "roadworker" {
  name = "RoadworkerLambdaBackupRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "s3policy-document" {

  statement {
    sid = "ListBucketForBackupBucket"
    actions = [
      "s3:ListBuckets",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "FullAccessForBackupBucketOnly"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.backupbucket.bucket}/${var.s3prefix}*"
    ]
  }
}

resource "aws_iam_policy" "s3policy" {
  name = "RoadworkerSaveToBucketPolicy"
  description = "Policy to allow Roadworker to write backups to S3 bucket"
  path = "/"
  policy = "${data.aws_iam_policy_document.s3policy-document.json}"
}

resource "aws_iam_role_policy_attachment" "roadworkers32policy" {
  role = "${aws_iam_role.roadworker.name}"
  policy_arn = "${aws_iam_policy.s3policy.arn}"
}

resource "aws_iam_role_policy_attachment" "route53readonly" {
  role = "${aws_iam_role.roadworker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambdaexecution" {
  role = "${aws_iam_role.roadworker.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_s3_bucket" "backupbucket" {
  bucket = "${var.s3bucketname}"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id = "route53backups"
    prefix = "${var.s3prefix}/"
    enabled = true

    noncurrent_version_expiration {
      days = 30
    }

    expiration {
      days = 366
    }
  }

  tags {
    Name = "Route53BackupBucket"
    Description = "Backup bucket for Route53 using github.com/winebarrel/roadworker - utilized by lambda function"
  }
}

resource "aws_lambda_function" "roadworker" {
  filename = "roadwork.zip"
  function_name = "RoadworkerRoute53Backup"
  runtime = "python2.7"
  timeout = 30
  description = "Route53 backup to S3 using github.com/winebarrel/roadworker"
  role = "${aws_iam_role.roadworker.arn}"
  handler = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256(file("roadwork.zip"))}"
  environment {
    variables = {
      S3BUCKET = "${var.s3bucketname}"
      S3PREFIX = "${var.s3prefix}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "roadworker_scheduler" {
  name = "roadworker_scheduler"
  description = "Execute every 6 hours"
  schedule_expression = "rate(6 hours)"
}

resource "aws_cloudwatch_event_target" "call_roadworker_scheduled" {
  rule = "${aws_cloudwatch_event_rule.roadworker_scheduler.name}"
  target_id = "${aws_lambda_function.roadworker.function_name}"
  arn = "${aws_lambda_function.roadworker.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_roadworker" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.roadworker.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.roadworker_scheduler.arn}"
}
