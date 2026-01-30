pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    stages {

        stage('AWS Test') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    bat 'aws sts get-caller-identity'
                }
            }
        }

        stage('Infra provisioning') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    dir('terraform') {
                        bat """
                            "C:\\Program Files\\Terraform\\terraform.exe" init
                            "C:\\Program Files\\Terraform\\terraform.exe" plan
                            "C:\\Program Files\\Terraform\\terraform.exe" apply -auto-approve
                        """
                    }
                }
            }
        }

        stage('Generate static_inventory') {
            steps {
                script {
                    // Fetch Terraform outputs
                    def ubuntu_ip = bat(script: '"C:\\Program Files\\Terraform\\terraform.exe" -chdir=terraform output -raw ubuntu_public_ip', returnStdout: true).trim()
                    def amazon_ip = bat(script: '"C:\\Program Files\\Terraform\\terraform.exe" -chdir=terraform output -raw amazon_linux_public_ip', returnStdout: true).trim()

                    // Create static_inventory file at workspace root
                    writeFile file: 'static_inventory', text: """
[ubuntu]
${ubuntu_ip}

[amazon_linux]
${amazon_ip}
"""
                }
            }
        }

        stage('Commit static_inventory file into GitHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-creds',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    bat """
                        git config user.email "yashaswitirole28@gmail.com"
                        git config user.name "Yashaswitir28"
                        if exist static_inventory (
                            git add static_inventory
                            git commit -m "static_inventory file added by Jenkins Pipeline" || echo Nothing to commit
                            git push https://%GIT_USER%:%GIT_TOKEN%@github.com/Yashaswitir28/jenkins-terraform-ansible.git HEAD:main
                        ) else (
                            echo static_inventory does not exist, skipping commit
                        )
                    """
                }
            }
        }

        stage('Ansible via AWS SSM') {
            steps {
                bat """
                    ansible -i static_inventory docker_installation_playbook.yaml
                """
            }
        }

        stage('Proceed to destroy infra?') {
            steps {
                input message: 'Destroy AWS resources?'
            }
        }

        stage('Destroying infra') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    dir('terraform') {
                        bat '"C:\\Program Files\\Terraform\\terraform.exe" destroy -auto-approve'
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed – infra NOT destroyed automatically"
        }
        always {
            cleanWs()
        }
    }
}
