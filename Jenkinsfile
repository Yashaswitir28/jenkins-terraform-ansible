pipeline {
    agent {label 'common'}
    environment{
        credentials('aws-credentials')
    }
    stages {
        stage('Cloning') {
            steps {
                checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/shamimice03/jenkins-terraform-ansible.git']])
            }
        }
        stage('AWS Test') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }
        stage('Infra provisioning') {
            steps {
                sh """
                    cd infra-using-terraform
                    terraform init
                    terraform plan
                    terraform apply --auto-approve
                """
            }
        }
         stage('Commit static_inventory file into github') {
            steps {
                sh "git status"
                sh "git config user.email shamimice03@gmail.com"
                sh "git config user.name shamim"
                sh "git add ."
                sh "git commit -m 'staic_inventory file added by Jenkins Pipeline'"
                sh "git push https://${GITHUB_CRED_USR}:${GITHUB_CRED_PSW}@github.com/${GITHUB_CRED_USR}/jenkins-terraform-ansible.git HEAD:main"
            }
        }
         stage('Ansible-Install docker on remote hosts') {
            agent {label 'ansible'}
            steps {
                ansiblePlaybook credentialsId: 'ec2-ssh-key', disableHostKeyChecking: true, installation: 'ansible', inventory: 'static_inventory', playbook: 'docker_installation_playbook.yaml'            
            }
        }
         stage('Procced to destroy the infra ?') {
            steps {
                input message: 'Destroy aws resources?'
            }
        }
        stage('Destroying infra') {
            steps {
                sh 'cd infra-using-terraform; terraform destroy --auto-approve'
            }
        }
    }
     post { 
        always { 
            sh 'cd infra-using-terraform; terraform destroy --auto-approve'
            sh 'git status'
            sh "git add ."
            sh "git commit -m 'staic_inventory file removed by Jenkins Pipeline'"
            sh "git push https://${GITHUB_CRED_USR}:${GITHUB_CRED_PSW}@github.com/${GITHUB_CRED_USR}/terraform-ansible-jenkins.git HEAD:main"
            cleanWs()
        }
    }

}

