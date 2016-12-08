aws codebuild create-project --cli-input-json file://codebuild-project.json
aws codebuild start-build --project-name roadworker-lambda
