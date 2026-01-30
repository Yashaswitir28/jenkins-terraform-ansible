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
                        credentialsId: 'aws-creds',
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
                            credentialsId: 'aws-creds',
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
                            credentialsId: 'aws-creds',
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
                            credentialsId: 'aws-creds',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" apply -auto-approve tfplan"
                    }
                }
            }
        }

        stage('Generate Ansible Inventory') {
            steps {
                echo "Generating static inventory for Ansible..."
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding', 
                            credentialsId: 'aws-creds',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        script {
                            // Get IPs from Terraform outputs - use @echo off to suppress command echo
                            def ubuntuIPsRaw = bat(
                                script: "@echo off && \"${TERRAFORM_PATH}\" output -json ubuntu_public_ip", 
                                returnStdout: true
                            ).trim()
                            
                            def amazonIPsRaw = bat(
                                script: "@echo off && \"${TERRAFORM_PATH}\" output -json amazon_linux_public_ip", 
                                returnStdout: true
                            ).trim()

                            // Extract JSON portion (starts with '[')
                            def ubuntuIPsJson = ubuntuIPsRaw.substring(ubuntuIPsRaw.indexOf('['))
                            def amazonIPsJson = amazonIPsRaw.substring(amazonIPsRaw.indexOf('['))

                            echo "Ubuntu IPs JSON: ${ubuntuIPsJson}"
                            echo "Amazon IPs JSON: ${amazonIPsJson}"

                            // Parse JSON
                            def ubuntuIPs = new groovy.json.JsonSlurper().parseText(ubuntuIPsJson)
                            def amazonIPs = new groovy.json.JsonSlurper().parseText(amazonIPsJson)

                            // Build inventory content
                            def inventory = "[ubuntu]\n"
                            ubuntuIPs.each { ip -> 
                                inventory += "${ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa\n" 
                            }

                            inventory += "\n[amazon-linux]\n"
                            amazonIPs.each { ip -> 
                                inventory += "${ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_rsa\n" 
                            }

                            inventory += "\n[all:vars]\n"
                            inventory += "ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n"

                            // Write inventory file
                            writeFile file: "${WORKSPACE_DIR}\\static_inventory", text: inventory
                            echo "Static inventory created successfully:"
                            echo "${inventory}"
                        }
                    }
                }
            }
        }

        stage('Wait for Instances') {
            steps {
                echo "Waiting for EC2 instances to be ready..."
                sleep time: 30, unit: 'SECONDS'
            }
        }

        stage('Commit Inventory to Git') {
            steps {
                echo "Committing static_inventory to Git..."
                withCredentials([usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD')]) {
                    dir("${WORKSPACE_DIR}") {
                        script {
                            bat '''
                                git config user.email "yashaswitirole28@gmail.com"
                                git config user.name "Yashaswitir28"
                                git add static_inventory
                                git diff-index --quiet HEAD || git commit -m "Update static_inventory [skip ci]"
                            '''
                            
                            // Push only if there are changes
                            def pushResult = bat(
                                script: "git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/Yashaswitir28/jenkins-terraform-ansible.git HEAD:main",
                                returnStatus: true
                            )
                            
                            if (pushResult == 0) {
                                echo "Inventory pushed to Git successfully"
                            } else {
                                echo "No changes to push or push failed (non-critical)"
                            }
                        }
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                echo "Running Ansible playbook to install Docker..."
                dir("${WORKSPACE_DIR}") {
                    bat 'ansible-playbook -i static_inventory docker_installation_playbook.yaml -v'
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo "Deployment completed successfully!"
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
                            credentialsId: 'aws-creds',
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
