# Running roadworker in AWS Lambda to backup Route 53

Cheap and low-maintenance solution to back up Route53 to S3 using AWS Lambda.

![Dashsoft](https://dashsoft.dk/static/images/logo.png "Dashsoft logo")

Blog post: TBD

Website: [https://dashsoft.dk](https://dashsoft.dk)


## Installing

### Prerequisites

Download and copy packer and terraform to a bin directory in your path.

The [Getting Started](https://www.terraform.io/intro/getting-started/install.html) guide for Terraform
might be helpful.

Packer also has an [installation guide](https://www.packer.io/docs/installation.html).

### Building the Lambda code

You should check that the ```source_ami``` specified in [build_lambda.json](../master/build_lambda.json)
 (ami-f9dd458a) still corresponds to [the current lambda 
environment](http://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html "Lambda Execution Environment
and Available Libraries").

You must change the ```region``` and also the ```source_ami```if you prefer to run your instances in another region than 
eu-west-1.

Now create the Lambda code with Packer. Usually, I've already [configured an profile with the AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles) 
and set it up in an ```AWS_PROFILE``` environment variable, but there's now a wide range of options for safely managing
and providing AWS credentials ([AWS Vault](https://github.com/99designs/aws-vault), 
[awsudo](https://github.com/makethunder/awsudo), [instance 
profiles](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html))

Now run packer to build the zip-file containing Lambda code:

```
# packer build build_lambda.json
```

This command runs for a couple of minutes. Don't be alarmed when it seems to fail with the exit code 137, this is
completely intentional. We want to break out of Packer before any AMI's gets created but after our Ruby/Lambda artifact 
has been produced and downloaded (roadwork.zip). The last lines of the output should look approximately like this:

```
...
==> amazon-ebs: Downloading roadwork.zip => roadwork.zip
==> amazon-ebs: Provisioning with shell script: /var/folders/zz/cf94tq19037gbx8kl0mtl53c0000gn/T/packer-shell712020110
==> amazon-ebs: Terminating the source AWS instance...
==> amazon-ebs: Cleaning up any extra volumes...
==> amazon-ebs: No volumes to clean up, skipping
==> amazon-ebs: Deleting temporary security group...
Build 'amazon-ebs' errored: Script exited with non-zero exit status: 137

==> Some builds didn't complete successfully and had errors:
--> amazon-ebs: Script exited with non-zero exit status: 137

==> Builds finished but no artifacts were created.
```

Now check if a file named roadwork.zip has appeared in the current directory. If it's there, then you're good to 
continue, otherwise you'll have to look into the output of packer.

In that case, Packer has a [debug mode](https://www.packer.io/docs/other/debugging.html) that can come in handy.

The build server that Packer boots up needs access to the internet, so don't boot it up in a VPC or subnet that hasn't
got internet access.

### Deploying the Lambda function

Running Roadworker requires a few resources: An IAM Role with permissions to read from Route53 and permissions to write
to an S3 bucket. Also: An S3 bucket with versioning turned on. I've also turned on lifecycle management to purge old 
backups after a year.

The Lambda function should also be hooked up to a scheduled
[cloudwatch event rule](https://www.terraform.io/docs/providers/aws/r/cloudwatch_event_rule.html).
I've choosen a schedule that triggers the backup every 6 hours.

These resources could easily be set up by hand, but I've included a Terraform file to make it a bit easier to deploy.

You should review the route53-backup.tf file, edit the ```s3bucketname``` variable and change it from
```hennings-roadworker-backup-bucket``` to something that's unique for your account. Then run a Terraform plan to 
review the resources that are to be created:

```
# terraform plan
```

Create the resources with:

```
# terraform apply
```

There's now a terraform.tfstate file in the directory. If you ever want to change or modify the infrastructure that
you just created, then you need to save- and manage this file.

There's a range of options for doing this - see the Terraform documentation on
[Remote State](https://www.terraform.io/docs/state/remote/index.html) 
[Terragrunt](https://blog.gruntwork.io/add-automatic-remote-state-locking-and-configuration-to-terraform-with-terragrunt-656a57565a4d).

Loosing your Terraform state file is usually a pretty bad thing, but in this case, the number of resources isn't very
high. If you happen to delete the state file, then just delete the resources (the Lambda function named RoadworkerRoute53Backup,
the IAM Role named RoadworkerLambdaBackupRole and possibly the S3 bucket) in the console and re-create them with Teraform.

### Testing the Lambda function

The easiest way to test the Lambda function would be to go to the Lambda page in the AWS Console, find and choose the
function RoadworkerRoute53Backup, select _Test function_ on the _Actions_ drop-down, choose _Scheduled Event_ in the
_Sample event list_ and then _Save and test_ - before verifying that the Execution result section shows success.

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
Lambda Cloudwatch logstream where it could be picked up and published as a metric by a  
[Cloudwatch Logs metric filters](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_metric_filter.html).

The AWS documentations has [more information about how to filter 
and monitor log data](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html).

Add [CloudWatch Alarms](https://www.terraform.io/docs/providers/aws/r/cloudwatch_metric_alarm.html) to the Terraform
script that checks the lambda- and custom metric to make sure that the backup runs with the frequency that you expect, 
that the backup file isn't suspiciously small and that the Lambda function doesn't have failed invocations.

### Use Traveling Ruby

Figure out how to add unsupported native gems to [Traveling Ruby](http://phusion.github.io/traveling-ruby/). One drawback
of Traveling Ruby is that it supports a limited set of Ruby versions. It is debatable if shaving off a few extra MB's
are worth the effort.

### Replace Packer with Docker/CodeBuild

There's now [a docker image of Amazon Linux](https://hub.docker.com/_/amazonlinux/) that might be usable for 
compiling/assembling software to go into Lambda functions without spinning up EC2 instances using Packer.

Here's [the obligatory Jeff Barr blog post](https://aws.amazon.com/blogs/aws/new-amazon-linux-container-image-for-cloud-and-on-premises-workloads/).

The official Docker image is Amazon Linux 2016.09, but it's not the officially sanctioned Lambda environment
(amzn-ami-hvm-2016.03.3.x86_64-gp2). Regardless, it might produce binaries that are "compatible enough" to work.

A newer, better option could be CodeBuild, which has [build environments](http://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html)
that seems closer to the current Lambda environment.
