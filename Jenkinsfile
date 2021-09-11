pipeline {
    parameters {
        choice(name: 'action', choices: 'create\ndestroy', description: 'Action to create AKS EKS cluster')
        string(name: 'cluster_name', defaultValue: 'demo', description: 'EKS cluster name')
        string(name: 'terraform_version', defaultValue: '0.14.6', description: 'Terraform version')
        string(name: 'git_user', defaultValue: 'kodekolli', description: 'Enter github username')
    }

    agent any
    environment {
        VAULT_TOKEN = credentials('vault_token')
        USER_CREDENTIALS = credentials('DockerHub')
        registryCredential = 'DockerHub'
        dockerImage = ''
    }

    stages {
        stage('Retrieve AKS creds and Docker creds from vault'){
            when { expression { params.action == 'create' } }
            steps {
                script {
                    def host=sh(script: 'curl ifconfig.me', returnStdout: true)
                    echo "$host"
                    sh "export VAULT_ADDR=http://${host}:8200"
                    sh 'export VAULT_SKIP_VERIFY=true'
                    sh "curl --header 'X-Vault-Token: ${VAULT_TOKEN}' --request GET http://${host}:8200/v1/MY_CREDS/data/secret > mycreds.json"
                    sh 'cat mycreds.json | jq -r .data.data.ARM_CLIENT_ID > ARM_CLIENT_ID.txt'
                    sh 'cat mycreds.json | jq -r .data.data.ARM_CLIENT_SECRET > ARM_CLIENT_SECRET.txt'
                    sh 'cat mycreds.json | jq -r .data.data.ARM_SUBSCRIPTION_ID > ARM_SUBSCRIPTION_ID.txt'
                    sh 'cat mycreds.json | jq -r .data.data.ARM_TENANT_ID > ARM_TENANT_ID.txt'
                    sh 'cat mycreds.json | jq -r .data.data.sonar_token > sonar_token.txt'
                    ARM_CLIENT_ID = readFile('ARM_CLIENT_ID.txt').trim()
                    ARM_CLIENT_SECRET = readFile('ARM_CLIENT_SECRET.txt').trim()
                    ARM_SUBSCRIPTION_ID = readFile('ARM_SUBSCRIPTION_ID.txt').trim()
                    ARM_CLIENT_SECRET = readFile('ARM_CLIENT_SECRET.txt').trim()
                    ARM_TENANT_ID = readFile('ARM_TENANT_ID.txt').trim()            
                }
            }
        }
        stage('clone repo') {
            steps {
                git url:"https://github.com/${params.git_user}/azure-single-branch-infra.git", branch:'main'
            }
        }
        stage('Prepare the setup') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    currentBuild.displayName = "#" + env.BUILD_ID + " " + params.action + " eks-" + params.cluster_name
                    plan = params.cluster_name + '.plan'
                    TF_VERSION = params.terraform_version
                }
            }
        }
        stage('Check terraform PATH'){
            when { expression { params.action == 'create' } }
            steps {
                script{
                    echo 'Installing Terraform'
                    sh "wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
                    sh "unzip terraform_${TF_VERSION}_linux_amd64.zip"
                    sh 'sudo mv terraform /usr/bin'
                    sh "curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/kubectl"
                    sh 'chmod +x ./kubectl'
                    sh 'sudo mv kubectl /usr/bin'
                    sh "rm -rf terraform_${TF_VERSION}_linux_amd64.zip"
                    echo "Copying Azure cred to ${HOME} directory"
                    sh "mkdir -p $HOME/.azure"
                    sh """
                    set +x
                    cat <<-EOF | tee $HOME/.azure/config
[cloud]
ARM_CLIENT_ID=${ARM_CLIENT_ID}
ARM_CLIENT_SECRET=${ARM_CLIENT_SECRET}
ARM_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID}
ARM_TENANT_ID=${ARM_TENANT_ID}"""                    
                }
                sh 'terraform version'
                sh 'kubectl version --short --client'

            }
        } 
        stage ('Run Terraform Plan') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    sh 'terraform init'
                    sh "terraform plan -var cluster-name=${params.cluster_name} -var client_id=${ARM_CLIENT_ID} -var client_secret=${ARM_CLIENT_SECRET} -var subscription_id=${ARM_SUBSCRIPTION_ID} -var tenant_id=${ARM_TENANT_ID} -out ${plan}"
                }
            }
        }      
        stage ('Deploy Terraform Plan ==> apply') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    if (fileExists('$HOME/.kube')) {
                        echo '.kube Directory Exists'
                    } else {
                        sh 'mkdir -p $HOME/.kube'
                    }
                    echo 'Running Terraform apply'
                    sh 'terraform apply -var client_id=${ARM_CLIENT_ID} -var client_secret=${ARM_CLIENT_SECRET} -var subscription_id=${ARM_SUBSCRIPTION_ID} -var tenant_id=${ARM_TENANT_ID} -auto-approve ${plan}'
                    sh 'terraform output -raw kubeconfig > $HOME/.kube/config'
                    sh 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
                    sh 'sudo mkdir -p /root/.kube'
                    sh 'sudo mkdir -p /root/.azure'
                    sh 'sudo cp $HOME/.kube/config /root/.kube'
                    sh 'sudo cp $HOME/.azure/config /root/.azure'
                    sleep 30
                    sh 'kubectl get nodes'
                }
            }   
        }
        stage ('Deploy Monitoring') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    echo 'Deploying promethus and grafana using Ansible playbooks and Helm chars'
                    sh 'ansible-galaxy collection install -r requirements.yml'
                    sh 'ansible-playbook helm.yml --user jenkins'
                    sh 'sleep 20'
                    sh 'kubectl get all -n grafana'
                    sh 'kubectl get all -n prometheus'
                    sh 'export ELB=$(kubectl get svc -n grafana grafana -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")'
                }
            }
        }
        stage('Code Quality Check via SonarQube') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    dir('python-jinja2-login'){
                        def host=sh(script: 'curl ifconfig.me', returnStdout: true)
                        echo "$host"
                        git url:"https://github.com/${params.git_user}/python-jinja2-login.git", branch:'master'
                        sh "/opt/sonarscanner/bin/sonar-scanner \
                        -Dsonar.projectKey=python-login \
                        -Dsonar.projectBaseDir=/var/lib/jenkins/workspace/$JOB_NAME/python-jinja2-login \
                        -Dsonar.sources=. \
                        -Dsonar.language=py \
                        -Dsonar.host.url=http://${host}:9000 \
                        -Dsonar.login=${SONAR_TOKEN}"                        
                    }
                }
            }
        }
        stage('Deploying sample application to EKS cluster') {
            when { expression { params.action == 'create' } }
            steps {
                script{
                    dir('python-jinja2-login'){
                        echo "Building docker image"
                        dockerImage = docker.build("${USER_CREDENTIALS_USR}/azure-single-branch-infra:${env.BUILD_ID}")
                        echo "Pushing the image to registry"
                        docker.withRegistry( 'https://registry.hub.docker.com', registryCredential ) {
                            dockerImage.push("latest")
                            dockerImage.push("${env.BUILD_ID}")
                        }
                        echo "Deploy app to EKS cluster"
                        sh 'ansible-playbook python-app.yml --user jenkins -e action=present -e config=$HOME/.kube/config'
                        sleep 10
                        sh 'export APPELB=$(kubectl get svc -n default helloapp-svc -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")'
                    }
                }
            }
        }
        stage ('Run Terraform destroy'){
            when { expression { params.action == 'destroy' } }
            steps {
                script {
                    dir('python-jinja2-login'){
                        sh 'kubectl delete ns grafana || true'
                        sh 'kubectl delete ns prometheus || true'
                        sh 'ansible-playbook python-app.yml --user jenkins -e action=absent -e config=$HOME/.kube/config || true'
                    }
                        sh 'terraform destroy -var client_id=${ARM_CLIENT_ID} -var client_secret=${ARM_CLIENT_SECRET} -var subscription_id=${ARM_SUBSCRIPTION_ID} -var tenant_id=${ARM_TENANT_ID} -auto-approve $plan'
                    
                }
            }
        }
    }
}
