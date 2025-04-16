docker build -t web-app -f Dockerfile . 

docker build -t mysql-app -f Dockerfile_mysql .

docker network create my-network

docker run -d \
  --name mysql-container \
  --network my-network \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=employees \
  mysql-app


docker run -d \
  --name web-app \
  --network my-network \
  -p 81:8080 \
  -e DBHOST=mysql-container \
  -e DBUSER=root \
  -e DBPWD=rootpassword \
  -e DATABASE=employees \
  -e APP_COLOR=lime \
  -e DBPORT=3306 \
  web-app
  
  
# disable default aws credential and put you own credentials
/usr/local/bin/aws cloud9 update-environment --environment-id $C9_PID  --managed-credentials-action DISABLE
rm -vf ${HOME}/.aws/credentials
vi ~/.aws/credentials
aws sts get-caller-identity
sudo yum -y install jq gettext bash-completion
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin

# Enable eksctl bash completion
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

eksctl create cluster -f eks_config.yaml


#-----------------------------------------------------------

# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 097656145156.dkr.ecr.us-east-1.amazonaws.com

# docker tag web-app:latest 097656145156.dkr.ecr.us-east-1.amazonaws.com/clo835-app:latest
# docker push 097656145156.dkr.ecr.us-east-1.amazonaws.com/clo835-app:latest

# docker tag  mysql-app:latest 097656145156.dkr.ecr.us-east-1.amazonaws.com/mysql-repo:latest
# docker push 097656145156.dkr.ecr.us-east-1.amazonaws.com/mysql-repo:latest

#------------------------------------------------------------
# mount extra storage to cloud9 after increase EBS size
lsblk
sudo growpart /dev/nvme0n1 1
sudo xfs_growfs -d /
df -h


#------------------------------------------------------------
# inside CLO835_FinalProject_Deployemnt-main/k8s
bash init_kind.yaml
alias k=kubectl

# inside the final folder
k create ns final

# To add EKS cluster into kubeconfig 
aws eks update-kubeconfig --region us-east-1 --name clo835

# chnage cluster from kind to EKS
 kubectl config get-contexts

# new cluster name
kubectl config use-context <EKS cluster name>

#----------------------------------------
k create ns final

#Provision GP2
k apply -k 'github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.32'

#SA > Role > Role-Binding
k apply -f ./storage-account/sa.yaml
k apply -f ./storage-account/role.yaml
k apply -f ./storage-account/role-binding.yaml

# Test SA
kubectl get namespaces --as=system:serviceaccount:final:clo835
k describe clusterroles clo835-ns-admin  


#------------------------------
# secrets

# create secret through .yaml file
# 1. create mysql-db/secrets.yaml
# kubectl delete secret db-secret -n final
kubectl apply -f mysql-db/secrets.yaml

k apply -f ./mysql-db/secrets.yaml
k apply -f ./mysql-db/pvc.yaml
k apply -f ./mysql-db/headless.yaml
k apply -f ./mysql-db/deployment.yaml

# 2. app-secret
kubectl delete secret app-secrets -n final
k create secret generic app-secrets --from-env-file=./web-app/configs/secrets.conf -n final

k apply -f ./web-app/configMap.yaml
k apply -f ./web-app/service.yaml
k apply -f ./web-app/deployment.yaml

#------------------------------------
# delete the current nodegroup, becasue there are limit in number of pods with t3.micro nodes
eksctl delete nodegroup \
  --cluster clo835 \
  --name nodegroup \
  --region us-east-1
  
  
# create a new node group, with nodes t3.medium
# after this we can have enough space for new pods
eksctl create nodegroup \
  --cluster clo835 \
  --name medium-nodegroup \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed \
  --region us-east-1 \
  # --ssh-access \
  # --ssh-public-key <your-key-name>


#-----------------------
# create a new nodegroup and then delete a old nodegroup
# new nodegroup
eksctl create nodegroup --config-file=your-config.yaml

# delete old nodegroup
eksctl delete nodegroup --cluster=your-cluster-name --name=old-nodegroup-name

#----------------------
# see logs inside the pod
kubectl logs <pod-name> -n <namespace>


#------------------------
 k apply -f configMap.yaml -n final
 k apply -f deployment.yaml -n final 

#---------------------
#run app locally
 $ export DBHOST=127.0.0.1
 export DBUSER=root
 export DBPWD=rootpassword
 export DATABASE=employees
 export APP_COLOR=lime
 export DBPORT=3306
 
 python3 app.py




#clean up
k delete ns final
eksctl delete cluster --name clo835 --region us-east-1