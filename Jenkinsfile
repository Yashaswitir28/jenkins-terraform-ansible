pipeline {
    agent any

    environment {
        TERRAFORM_PATH = "C:\\Program Files\\Terraform\\terraform.exe"
        WORKSPACE_DIR = "${env.WORKSPACE}"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                echo "Checking out code from SCM..."
                checkout scm
            }
        }

        stage('Verify AWS Credentials') {
            steps {
                echo "Testing AWS credentials..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    bat '''
                        echo AWS credentials loaded
                        aws sts get-caller-identity
                    '''
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

        stage('Terraform Plan') {
            steps {
                echo "Running Terraform plan..."
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
                            // Get instance IDs from Terraform outputs
                            def ubuntuIDsRaw = bat(
                                script: "@echo off && \"${TERRAFORM_PATH}\" output -json ubuntu_instance_id", 
                                returnStdout: true
                            ).trim()
                            
                            def amazonIDsRaw = bat(
                                script: "@echo off && \"${TERRAFORM_PATH}\" output -json amazon_linux_instance_id", 
                                returnStdout: true
                            ).trim()

                            // Extract JSON portion
                            def ubuntuIDsJson = ubuntuIDsRaw.substring(ubuntuIDsRaw.indexOf('['))
                            def amazonIDsJson = amazonIDsRaw.substring(amazonIDsRaw.indexOf('['))

                            // Parse JSON
                            def ubuntuIDs = new groovy.json.JsonSlurper().parseText(ubuntuIDsJson)
                            def amazonIDs = new groovy.json.JsonSlurper().parseText(amazonIDsJson)

                            // Store in environment variables
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
            steps {
                echo "Waiting for SSM agent to be ready on instances..."
                sleep time: 60, unit: 'SECONDS'
            }
        }

        stage('Install Docker on Ubuntu') {
            steps {
                echo "Installing Docker on Ubuntu instance via SSM..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    script {
                        bat """
                            aws ssm send-command ^
                                --instance-ids ${env.UBUNTU_INSTANCE_ID} ^
                                --document-name "AWS-RunShellScript" ^
                                --parameters "commands=['sudo apt-get update -y','sudo apt-get install -y docker.io','sudo systemctl start docker','sudo systemctl enable docker','sudo usermod -aG docker ubuntu']" ^
                                --output text ^
                                --query "Command.CommandId" > ubuntu_command_id.txt
                        """
                        
                        def ubuntuCommandId = readFile('ubuntu_command_id.txt').trim()
                        echo "Ubuntu command ID: ${ubuntuCommandId}"
                        
                        // Wait for command to complete
                        sleep time: 30, unit: 'SECONDS'
                        
                        bat """
                            aws ssm get-command-invocation ^
                                --command-id ${ubuntuCommandId} ^
                                --instance-id ${env.UBUNTU_INSTANCE_ID} ^
                                --query "Status" ^
                                --output text
                        """
                    }
                }
            }
        }

        stage('Install Docker on Amazon Linux') {
            steps {
                echo "Installing Docker on Amazon Linux instance via SSM..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    script {
                        bat """
                            aws ssm send-command ^
                                --instance-ids ${env.AMAZON_INSTANCE_ID} ^
                                --document-name "AWS-RunShellScript" ^
                                --parameters "commands=['sudo yum update -y','sudo yum install -y docker','sudo systemctl start docker','sudo systemctl enable docker','sudo usermod -aG docker ec2-user']" ^
                                --output text ^
                                --query "Command.CommandId" > amazon_command_id.txt
                        """
                        
                        def amazonCommandId = readFile('amazon_command_id.txt').trim()
                        echo "Amazon Linux command ID: ${amazonCommandId}"
                        
                        // Wait for command to complete
                        sleep time: 30, unit: 'SECONDS'
                        
                        bat """
                            aws ssm get-command-invocation ^
                                --command-id ${amazonCommandId} ^
                                --instance-id ${env.AMAZON_INSTANCE_ID} ^
                                --query "Status" ^
                                --output text
                        """
                    }
                }
            }
        }

        stage('Verify Docker Installation') {
            steps {
                echo "Verifying Docker installation on both instances..."
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    script {
                        echo "Checking Docker on Ubuntu..."
                        bat """
                            aws ssm send-command ^
                                --instance-ids ${env.UBUNTU_INSTANCE_ID} ^
                                --document-name "AWS-RunShellScript" ^
                                --parameters "commands=['docker --version']" ^
                                --output text
                        """
                        
                        echo "Checking Docker on Amazon Linux..."
                        bat """
                            aws ssm send-command ^
                                --instance-ids ${env.AMAZON_INSTANCE_ID} ^
                                --document-name "AWS-RunShellScript" ^
                                --parameters "commands=['docker --version']" ^
                                --output text
                        """
                    }
                }
            }
        }

        stage('Deployment Complete') {
            steps {
                echo "✅ Docker successfully installed on all instances via SSM!"
                echo "Infrastructure is running. Review before destroying..."
            }
        }

        stage('Approve Destruction') {
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        input message: 'Destroy the infrastructure?', ok: 'Destroy'
                    }
                }
            }
        }

        stage('Terraform Destroy') {
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
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
            echo "Check logs above for errors."
            echo "⚠️  Infrastructure may still be running - manual cleanup may be required"
        }
        aborted {
            echo "⚠️  Pipeline was aborted"
            echo "Infrastructure may still be running - please check AWS console"
        }
    }
}
