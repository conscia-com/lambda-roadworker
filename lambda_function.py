from __future__ import print_function

import os
import commands
import datetime
import boto3

s3bucket = os.environ["S3BUCKET"]
s3prefix = os.environ["S3PREFIX"] if "S3PREFIX" in os.environ else ''
datestring = datetime.datetime.now().strftime("%Y-%m-%d")

def lambda_handler(event, context):
    s3 = boto3.resource('s3')
    print(commands.getstatusoutput('./roadwork -e -o /tmp/Roadworker.rb'))
    key = '%s%s_Roadworker.rb' % (s3prefix, datestring)
    print("Uploading to: %s" % key)
    s3.Object(s3bucket, key).upload_file('/tmp/Roadworker.rb')
    backup_size = os.path.getsize("/tmp/Roadworker.rb")
    print("Route53BackupSize:%d" % backup_size)
