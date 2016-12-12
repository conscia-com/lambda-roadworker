{
    "name": "lambda-roadworker",
    "description": "Building lambda-roadworker source from github repo",
    "source": {
        "type": "GITHUB",
        "location": "https://github.com/dashsoftaps/lambda-roadworker.git"
    },
    "artifacts": {
        "type": "S3",
        "location": "${s3bucketname}",
        "namespaceType": "NONE",
        "name": "LambdaRoadworker.zip",
        "packaging": "ZIP"
    },
    "environment": {
        "type": "LINUX_CONTAINER",
        "image": "${codebuild_image}",
        "computeType": "BUILD_GENERAL1_SMALL",
        "environmentVariables": []
    },
    "serviceRole": "LambdaRoadworkerCodebuildRole",
    "timeoutInMinutes": 30,
    "tags": []
}
