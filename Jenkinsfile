pipeline {
    agent any

    environment {
        TERRAFORM_PATH = "C:\\Program Files\\Terraform\\terraform.exe"
        WORKSPACE_DIR = "${env.WORKSPACE}"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('AWS Test') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                ]) {
                    bat 'aws sts get-caller-identity'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                    ]) {
                        bat "\"${TERRAFORM_PATH}\" init"
                        bat "\"${TERRAFORM_PATH}\" plan"
                        bat "\"${TERRAFORM_PATH}\" apply -auto-approve"
                    }
                }
            }
        }

        stage('Generate static_inventory') {
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    script {
                        // Using -json to avoid the tuple/raw error
                        def ubuntuIPsJson = bat(script: "\"${TERRAFORM_PATH}\" output -json ubuntu_public_ip", returnStdout: true).trim()
                        def amazonIPsJson = bat(script: "\"${TERRAFORM_PATH}\" output -json amazon_linux_public_ip", returnStdout: true).trim()

                        // Parse JSON manually
                        def ubuntuIPs = new groovy.json.JsonSlurper().parseText(ubuntuIPsJson)
                        def amazonIPs = new groovy.json.JsonSlurper().parseText(amazonIPsJson)

                        def inventory = "[ubuntu]\n"
                        ubuntuIPs.each { ip -> inventory += "${ip}\n" }

                        inventory += "\n[amazon-linux]\n"
                        amazonIPs.each { ip -> inventory += "${ip}\n" }

                        writeFile file: "${WORKSPACE_DIR}\\static_inventory", text: inventory
                        echo "static_inventory file created:\n${inventory}"
                    }
                }
            }
        }

        stage('Commit static_inventory') {
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GIT_TOKEN')]) {
                    dir("${WORKSPACE_DIR}") {
                        bat 'git config user.email "yashaswitirole28@gmail.com"'
                        bat 'git config user.name "Yashaswitir28"'
                        bat 'git add static_inventory'
                        bat 'git commit -m "Update static_inventory" || echo No changes to commit'
                        bat "git push https://${GIT_TOKEN}@github.com/Yashaswitir28/jenkins-terraform-ansible.git HEAD:main"
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                dir("${WORKSPACE_DIR}") {
                    bat 'ansible-playbook -i static_inventory docker_installation_playbook.yaml'
                }
            }
        }

        stage('Destroy Terraform Infra') {
            steps {
                dir("${WORKSPACE_DIR}\\terraform") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
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
        echo "✅ Pipeline finished successfully"
    }
    failure {
        echo "❌ Pipeline failed – infra may not be destroyed automatically"
    }
}
