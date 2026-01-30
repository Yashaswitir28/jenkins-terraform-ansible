pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    stages {

        stage('Cloning') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Yashaswitir28/jenkins-terraform-ansible.git'
            }
        }

        stage('AWS Test') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh 'aws sts get-caller-identity'
                }
            }
        }

        stage('Infra provisioning') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh '''
                        cd infra-using-terraform
                        terraform init
                        terraform plan
                        terraform apply -auto-approve
                    '''
                }
            }
        }

        stage('Commit static_inventory file into GitHub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-creds',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN'
                    )
                ]) {
                    sh '''
                        git status
                        git config user.email "yashaswitirole28@gmail.com"
                        git config user.name "Yashaswitir28"

                        git add static_inventory
                        git commit -m "static_inventory file added by Jenkins Pipeline" || echo "Nothing to commit"

                        git push https://${GIT_USER}:${GIT_TOKEN}@github.com/Yashaswitir28/jenkins-terraform-ansible.git HEAD:main
                    '''
                }
            }
        }

        stage('Ansible via AWS SSM') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh '''
                        cd ansible
                        ansible-playbook \
                          -i static_inventory \
                          docker_installation_playbook.yaml
                    '''
                }
            }
        }

        stage('Proceed to destroy infra?') {
            steps {
                input message: 'Destroy AWS resources?'
            }
        }

        stage('Destroying infra') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh '''
                        cd infra-using-terraform
                        terraform destroy -auto-approve
                    '''
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

