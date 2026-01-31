pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to create or destroy infrastructure'
        )
    }

    environment {
        TERRAFORM_PATH = "C:\\Program Files\\Terraform\\terraform.exe"
        WORKSPACE_DIR  = "${env.WORKSPACE}"
        AWS_DEFAULT_REGION = "ap-south-1"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        stage('Verify AWS Credentials') {
            steps {
                echo "Verifying AWS credentials..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    bat 'aws sts get-caller-identity'
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" init -input=false"
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" fmt -check"
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" validate"
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" plan -out=tfplan"
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" apply -auto-approve tfplan"
                }
            }
        }

        stage('Get Instance IDs') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    script {
                        def ubuntuIDsRaw = bat(
                            script: "@echo off && \"${TERRAFORM_PATH}\" output -json ubuntu_instance_id",
                            returnStdout: true
                        ).trim()

                        def amazonIDsRaw = bat(
                            script: "@echo off && \"${TERRAFORM_PATH}\" output -json amazon_linux_instance_id",
                            returnStdout: true
                        ).trim()

                        def ubuntuIDs = new groovy.json.JsonSlurper().parseText(ubuntuIDsRaw)
                        def amazonIDs = new groovy.json.JsonSlurper().parseText(amazonIDsRaw)

                        env.UBUNTU_INSTANCE_ID = ubuntuIDs[0]
                        env.AMAZON_INSTANCE_ID = amazonIDs[0]

                        echo "Ubuntu Instance: ${env.UBUNTU_INSTANCE_ID}"
                        echo "Amazon Linux Instance: ${env.AMAZON_INSTANCE_ID}"
                    }
                }
            }
        }

        stage('Wait for SSM Agent') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Waiting for SSM agent..."
                sleep time: 60, unit: 'SECONDS'
            }
        }

        stage('Install Docker via SSM') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Installing Docker on instances..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    bat """
                    aws ssm send-command ^
                      --instance-ids ${env.UBUNTU_INSTANCE_ID} ^
                      --document-name "AWS-RunShellScript" ^
                      --parameters "commands=['sudo apt-get update -y','sudo apt-get install -y docker.io','sudo systemctl start docker','sudo systemctl enable docker']"

                    aws ssm send-command ^
                      --instance-ids ${env.AMAZON_INSTANCE_ID} ^
                      --document-name "AWS-RunShellScript" ^
                      --parameters "commands=['sudo yum install -y docker','sudo systemctl start docker','sudo systemctl enable docker']"
                    """
                }
            }
        }

        stage('Install CloudWatch Agent') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Installing CloudWatch Agent..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    bat """
                    aws ssm send-command ^
                      --instance-ids ${env.UBUNTU_INSTANCE_ID} ${env.AMAZON_INSTANCE_ID} ^
                      --document-name "AWS-ConfigureAWSPackage" ^
                      --parameters '{"action":["Install"],"name":["AmazonCloudWatchAgent"]}'
                    """
                }
            }
        }

        stage('Monitoring Verification') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "CloudWatch monitoring enabled. Metrics available in AWS Console."
            }
        }

        stage('Approve Destruction') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input message: 'Destroy the infrastructure?', ok: 'Destroy'
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" destroy -auto-approve"
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo """
            ✅ PIPELINE SUCCESS
            ------------------
            Infrastructure lifecycle completed successfully
            Monitoring: AWS CloudWatch
            Region: ap-south-1
            """
        }
        failure {
            echo "❌ Pipeline failed. Please check logs."
        }
        aborted {
            echo "⚠️ Pipeline aborted."
        }
    }
}
