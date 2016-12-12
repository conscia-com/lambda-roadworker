# Running roadworker in AWS Lambda to backup Route 53

Cheap and low-maintenance solution to back up Route53 to S3 using AWS Lambda.

![Dashsoft](https://dashsoft.dk/static/images/logo.png "Dashsoft logo")

Blog post: TK

Website: [https://dashsoft.dk](https://dashsoft.dk)


## Installing

### Prerequisites

[Download](https://releases.hashicorp.com/terraform/) and copy terraform to a bin directory in your path. The version 
should be 0.7.13 or higher — as we are going to need support for 
[Lambda Environment Variables](https://aws.amazon.com/about-aws/whats-new/2016/11/aws-lambda-supports-environment-variables/).
Also make sure that you have an updated version of the [AWS CLI](https://aws.amazon.com/cli/) (version 1.11.28 or higher - 
more recent than re:Invent 2016 as we need support for CodeBuild).

The [Getting Started](https://www.terraform.io/intro/getting-started/install.html) guide for Terraform and the 
[Getting Started](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) chapter for the AWS CLI might be helpful.

### Building the Lambda code

First, we need to create the Lambda zip file containing Roadworker installed in a Ruby environment by making a
CodeBuild project and running a build.

Clone the GitHub repository [dashsoftaps/lambda-roadworker](https://github.com/dashsoftaps/lambda-roadworker)

CodeBuild requires a few resources: An IAM Role that allows CodeBuild to output CloudWatch Logs and gives permission 
to write to an S3 bucket. Also: An S3 bucket for the Lambda zip file, which I will reuse for the backups.

I have turned on versioning and also lifecycle management on the bucket to purge old backups after a year and purge
non-current versions after a month.

The bucket name is specified in the [tf/terraform.tfvars](../master/tf/terraform.tfvars) file. It should be changed from
_hennings-roadworker-backup-bucket_ to something that is appropriately and unique for your account.

Compare the Build Environment Reference for AWS CodeBuild with 
[the current lambda environment](http://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html "Lambda 
Execution Environment and Available Libraries") to make sure that the
`codebuild_image` are compatible with the Lambda execution environment.

Now create the necessary infrastructure with Terraform. Usually, I've already 
[configured an profile with the AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles) 
and set it up in an ```AWS_PROFILE``` environment variable, but there's now a wide range of options for safely managing
and providing AWS credentials ([AWS Vault](https://github.com/99designs/aws-vault), 
[awsudo](https://github.com/makethunder/awsudo), [instance 
profiles](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html))

Change directory to `tf` to create the bucket and the policies. Cautious SysAdmins should probably run `terraform plan`
to review which resource that Terraform is about to create before running the `terraform apply` command:

```
$ cd tf
$ terraform apply
```

Terraform will run for a while and create 10 resources. Terraform does not yet support creating CodeBuild projects
natively (there is a [work-in-progress pull request](https://github.com/hashicorp/terraform/pull/10633), so support
should not be too far away). Until it is supported, the AWS CLI will have to be used to create the project and start
the build:

```
$ aws codebuild create-project --cli-input-json file://codebuild-project.json
$ aws codebuild start-build --project-name lambda-roadworker
```

The software that is being build by the CodeBuild project is specified in the [buildspec.yml](../master/buldspec.yml) file.

Follow the build phase of CodeBuild in the AWS Console.

If everything goes well, then the status of the build should end as Succeeded and a zipfile named LambdaRoadworker.zip
should exist in the bucket.

### Deploying the Lambda function

Running the RoadWorker Lambda function also requires a few resources: Mainly a Lambda function, a scheduled 
[cloudwatch event rule](https://www.terraform.io/docs/providers/aws/r/cloudwatch_event_rule.html) and a few resources
to connect the function and the event rule and allow the event rule to call the Lambda function.

For the event rule, I’ve chosen a schedule that triggers the backup every 6 hours.

Compared to the previous run, an additional flag needs to be passed to deploy the Lambda function. Run a Terraform plan
to review the resources that are to be created:

```
# terraform plan -var 'with_lambda=1'
```

Create the resources with:

```
# terraform apply -var 'with_lambda=1' 
```

There's now a terraform.tfstate file in the directory. If you ever want to change or modify the infrastructure that
you just created, then you need to save- and manage this file.

There's a range of options for doing this - see the Terraform documentation on
[Remote State](https://www.terraform.io/docs/state/remote/index.html) or consider using
[Terragrunt](https://blog.gruntwork.io/add-automatic-remote-state-locking-and-configuration-to-terraform-with-terragrunt-656a57565a4d).

Losing a Terraform state file is usually a pretty bad thing, but in this case, only a handful of resources is created. 
If you should lose the state file, then just delete the resources in the console (the Lambda function 
RoadworkerRoute53Backup, the IAM Roles prefixed with LambdaRoadworker and possibly the S3 bucket and CodeBuild 
project) and re-create them with Terraform.

### Testing the Lambda function

The easiest way to test the Lambda function would be to go to the Lambda page in the AWS Console, find and choose the
function RoadworkerRoute53Backup, select _Test function_ on the _Actions_ drop-down, choose _Scheduled Event_ in the
_Sample event list_ and then _Save and test_ - before verifying that the Execution result section shows success.

You could also just use the AWS CLI to invoke the function:

```
$ aws lambda invoke -function-name RoadworkerRoute53Backup /dev/null
```

If the function runs successfully, then you should find a timestamped file in the S3 bucket.

### Restoring data

Restoring or validating backups can be done from any server og PC with access to update Route53. Install roadworker
locally and download the needed backup file from S3. 

See the [Roadworker github page](https://github.com/winebarrel/roadworker) for additional documentation on which 
 arguments to use to test- and restore backup files.


## Alternate approaches and various improvements

### Backup results should be monitored

Monitoring tools and preferences certainly differs across organizations. An AWS-centric approach would be to publish 
the return codes and the size of the backup file as custom CloudWatch metrics using either 
[AWS CLI](http://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-data.html) 
or [boto3](http://boto3.readthedocs.io/en/latest/reference/services/cloudwatch.html#CloudWatch.Client.put_metric_data).

An alternative to explicitly publishing metrics would be to print out the size of the backup file from the
[python lambda handler](../master/lambda_function.py) in a format that's recognizable. It'll end up in the
Lambda Cloudwatch logstream where it could be picked up and published as a metric by 
a [Cloudwatch Logs metric filter](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_metric_filter.html).

The AWS documentations has [more information about how to filter 
and monitor log data](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html).

Add [CloudWatch Alarms](https://www.terraform.io/docs/providers/aws/r/cloudwatch_metric_alarm.html) to the Terraform
script that checks the lambda- and custom metric to make sure that the backup runs with the frequency that you expect, 
that the backup file isn't suspiciously small and that the Lambda function doesn't have failed invocations.

### Use Traveling Ruby

Figure out how to add unsupported native gems to [Traveling Ruby](http://phusion.github.io/traveling-ruby/). One drawback
of Traveling Ruby is that it supports a limited set of Ruby versions. It is debatable if shaving off a few extra MB's
are worth the effort and ease of building on rvm.

### Replace CodeBuild with Docker?

There's now [a docker image of Amazon Linux](https://hub.docker.com/_/amazonlinux/) that might be usable for 
compiling/assembling software to go into Lambda functions without using CodeBuild.

Here's [the obligatory Jeff Barr blog post](https://aws.amazon.com/blogs/aws/new-amazon-linux-container-image-for-cloud-and-on-premises-workloads/).

The official Docker image is Amazon Linux 2016.09, but it's not the officially sanctioned Lambda environment
(amzn-ami-hvm-2016.03.3.x86_64-gp2). Regardless, it might produce binaries that are "compatible enough" to work.
