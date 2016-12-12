#
# Codebuild resources
#

provider "aws" {
  region = "${var.region}"
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

data "template_file" "project-json" {
  template = "${file("${path.module}/codebuild-project.json.tpl")}"

  vars {
    s3bucketname = "${var.s3bucketname}"
    codebuild_image = "${var.codebuild_image}"
  }
}

resource "null_resource" "local" {
  triggers {
    template = "${data.template_file.project-json.rendered}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.project-json.rendered}' > ${var.filename}"
  }
}

resource "aws_iam_role" "codebuild" {
  name = "LambdaRoadworkerCodebuildRole"
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
      "arn:aws:s3:::${var.s3bucketname}/*"
    ]
  }

  statement {
    sid = "DenyAccessToBackupDirectory"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::${var.s3bucketname}/${var.s3prefix}*"
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
  name = "LambdaRoadworkerCodebuildPolicy"
  description = "Policy to allow CodeBuild to write artifacts to S3 bucket"
  path = "/"
  policy = "${data.aws_iam_policy_document.codebuild-document.json}"
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role = "${aws_iam_role.codebuild.name}"
  policy_arn = "${aws_iam_policy.codebuild.arn}"
}
