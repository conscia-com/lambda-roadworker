#
# Lambda resources for lambda-roadworker
#

resource "aws_iam_role" "roadworker" {
  name = "LambdaRoadworkerBackupRole"
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
      "arn:aws:s3:::${var.s3bucketname}/${var.s3prefix}*"
    ]
  }
}

resource "aws_iam_policy" "s3policy" {
  name = "RoadworkerSaveToBucketPolicy"
  description = "Policy to allow Roadworker to write backups to S3 bucket"
  path = "/"
  policy = "${data.aws_iam_policy_document.s3policy-document.json}"
}

resource "aws_iam_role_policy_attachment" "roadworkers3policy" {
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

resource "aws_lambda_function" "roadworker" {
  s3_bucket = "${var.s3bucketname}"
  s3_key = "LambdaRoadworker.zip"
  function_name = "RoadworkerRoute53Backup"
  runtime = "python2.7"
  timeout = 30
  description = "Route53 backup to S3 using github.com/winebarrel/roadworker"
  role = "${aws_iam_role.roadworker.arn}"
  handler = "lambda_function.lambda_handler"
  environment {
    variables = {
      S3BUCKET = "${var.s3bucketname}"
      S3PREFIX = "${var.s3prefix}"
    }
  }

  count = "${var.with_lambda}"
}

resource "aws_cloudwatch_event_rule" "roadworker_scheduler" {
  name = "roadworker_scheduler"
  description = "Execute every 6 hours"
  schedule_expression = "rate(6 hours)"

  count = "${var.with_lambda}"
}

resource "aws_cloudwatch_event_target" "call_roadworker_scheduled" {
  rule = "${aws_cloudwatch_event_rule.roadworker_scheduler.name}"
  target_id = "${aws_lambda_function.roadworker.function_name}"
  arn = "${aws_lambda_function.roadworker.arn}"

  count = "${var.with_lambda}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_roadworker" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.roadworker.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.roadworker_scheduler.arn}"

  count = "${var.with_lambda}"
}
