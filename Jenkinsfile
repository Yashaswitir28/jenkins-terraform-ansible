pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    stages {
        stage('AWS Test') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }
    }
}
