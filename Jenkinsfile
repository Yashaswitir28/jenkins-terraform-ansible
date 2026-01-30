pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        AWS_ACCESS_KEY_ID     = credentials('aws-credentials').accessKey
        AWS_SECRET_ACCESS_KEY = credentials('aws-credentials').secretKey
    }

    stages {
        stage('AWS Test') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }
    }
}

