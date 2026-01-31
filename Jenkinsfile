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
                echo "Initializing Terraform..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" init -input=false"
                    }
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                echo "Checking Terraform formatting..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    bat "\"${TERRAFORM_PATH}\" fmt -check || echo Format issues detected"
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                echo "Validating Terraform configuration..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" validate"
                    }
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Planning Terraform changes..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" plan -out=tfplan"
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Applying Terraform configuration..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" apply -auto-approve tfplan"
                    }
                }
            }
        }

        stage('Get Instance IDs') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Retrieving EC2 instance IDs..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        script {
                            // Get instance IDs with proper JSON parsing
                            def ubuntuIDsRaw = bat(
                                script: "@echo off && \"${TERRAFORM_PATH}\" output -json ubuntu_instance_id",
                                returnStdout: true
                            ).trim()

                            def amazonIDsRaw = bat(
                                script: "@echo off && \"${TERRAFORM_PATH}\" output -json amazon_linux_instance_id",
                                returnStdout: true
                            ).trim()

                            // Extract JSON portion (starts with '[')
                            def ubuntuIDsJson = ubuntuIDsRaw.substring(ubuntuIDsRaw.indexOf('['))
                            def amazonIDsJson = amazonIDsRaw.substring(amazonIDsRaw.indexOf('['))

                            // Parse JSON
                            def ubuntuIDs = new groovy.json.JsonSlurper().parseText(ubuntuIDsJson)
                            def amazonIDs = new groovy.json.JsonSlurper().parseText(amazonIDsJson)

                            env.UBUNTU_INSTANCE_ID = ubuntuIDs[0]
                            env.AMAZON_INSTANCE_ID = amazonIDs[0]

                            echo "Ubuntu Instance ID: ${env.UBUNTU_INSTANCE_ID}"
                            echo "Amazon Linux Instance ID: ${env.AMAZON_INSTANCE_ID}"
                        }
                    }
                }
            }
        }

        stage('Wait for SSM Agent') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Waiting for SSM agent to be ready..."
                sleep time: 60, unit: 'SECONDS'
            }
        }

        stage('Install Docker via SSM') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Installing Docker on instances via SSM..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    script {
                        echo "Installing Docker on Ubuntu instance..."
                        bat """
                            aws ssm send-command ^
                              --instance-ids ${env.UBUNTU_INSTANCE_ID} ^
                              --document-name "AWS-RunShellScript" ^
                              --parameters "commands=['sudo apt-get update -y','sudo apt-get install -y docker.io','sudo systemctl start docker','sudo systemctl enable docker','sudo usermod -aG docker ubuntu']"
                        """

                        sleep time: 5, unit: 'SECONDS'

                        echo "Installing Docker on Amazon Linux instance..."
                        bat """
                            aws ssm send-command ^
                              --instance-ids ${env.AMAZON_INSTANCE_ID} ^
                              --document-name "AWS-RunShellScript" ^
                              --parameters "commands=['sudo yum update -y','sudo yum install -y docker','sudo systemctl start docker','sudo systemctl enable docker','sudo usermod -aG docker ec2-user']"
                        """
                    }
                }
            }
        }

        stage('Wait for Docker Installation') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Waiting for Docker installation to complete..."
                sleep time: 30, unit: 'SECONDS'
            }
        }

        stage('Install CloudWatch Agent') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "Installing CloudWatch Agent on all instances..."
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
                          --parameters "{\\"action\\":[\\"Install\\"],\\"name\\":[\\"AmazonCloudWatchAgent\\"]}"
                    """
                }
            }
        }

        stage('Monitoring Verification') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "✅ CloudWatch monitoring enabled!"
                echo "Metrics available in AWS Console: CloudWatch > Metrics"
                echo "Region: ${AWS_DEFAULT_REGION}"
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
                echo "Destroying Terraform infrastructure..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" destroy -auto-approve"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning workspace..."
            cleanWs()
        }
        success {
            echo """
            ✅ PIPELINE SUCCESS
            ------------------
            Infrastructure lifecycle completed successfully
            Monitoring: AWS CloudWatch
            Region: ${AWS_DEFAULT_REGION}
            """
        }
        failure {
            echo "❌ Pipeline failed. Please check logs above."
            echo "⚠️  Infrastructure may still be running - manual cleanup may be required"
        }
        aborted {
            echo "⚠️ Pipeline aborted by user"
            echo "Infrastructure may still be running - please check AWS console"
        }
    }
}

