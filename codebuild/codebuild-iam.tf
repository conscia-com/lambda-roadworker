provider "aws" {
  region = "eu-west-1"
}

resource "aws_iam_role" "codebuild" {
  name = "RoadworkerLambdaCodebuildRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "codebuild-document" {

  statement {
    sid = "AllowListBuckets"
    actions = [
      "s3:ListBuckets",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "FullAccessForArtifactBucketOnly"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::lambda-roadworker/*"
    ]
  }

  statement {
    sid = "CloudWatchLogsPolicy"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "codebuild" {
  name = "RoadworkerLambdaCodebuildPolicy"
  description = "Policy to allow Roadworker to write artifacts to S3 bucket"
  path = "/"
  policy = "${data.aws_iam_policy_document.codebuild-document.json}"
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role = "${aws_iam_role.codebuild.name}"
  policy_arn = "${aws_iam_policy.codebuild.arn}"
}
