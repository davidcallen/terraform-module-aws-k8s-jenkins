Deploy Jenkins to Kubernetes Cluster
====================================

Overview
---------
The Goal is to :
- To run Jenkins and its Jobs (workers) within a Kubernetes cluster.
- The cluster could horizontally autoscale as demand increases.
- Use EFS storage so Jobs are persisted across nodes. i.e. a prpl build is retained enabling incremental builds.
- Use EFS CSI Driver (but currently using **statically** provisioned EFS volumes)
- Currently using Fargate for the k8s nodes (check works ok with EC2 nodes)

Workstation Setup
-----------------
You'll need tools installed via ```prpl/deploy/aws/scripts/cloud-dev-install.sh```
i.e. helm, kubectl, eksctl, docker

Deploy Jenkins
--------------
Deployment will be via terraform (and Helm) and the official Jenkins Helm Chart is [here](https://charts.jenkins.io/).

The below commands will create the :
- EFS Storage for Jenkins and the Agents
- k8s secrets for Jenkins
- Helm deploy Jenkins

Note : that Jenkins will deploy into the specified kubernetes namespace.


Configure Jenkins
-------------------
Jenkins can be fully configured via the helm chart values.yaml here :
cloud/terraform/ta/core/k8s-jenkins/README.md

The Helm chart passes this thru as Jenkins [ConfigAsCode](https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/README.md)
Currently the Jenkins System Config and Jobs are not in there so manually:
1) Install Subversion plugin.  
   Create a credential for it
   Set its version to 1.7 in System Config

2) Alter podTemplate in System Config > Configure Clouds > Pod Template 
   Add :
   Workspace Volume = PersistentVolumeClaimWorkspaceVolume
   ClaimName=ta-jenkins-agents-pvc
   Readonly=false

3) Create a new pipeline job for CI-PRPL.
Copy across the Jenkinsfile text from cloud/helm/jenkins/jobs/CI-PRPL/Jenkinsfile
   
All this config should be converted to CaC to capture it in code.
