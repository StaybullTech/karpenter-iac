# Deploy EKS cluster with Karpenter
This repository contains a [github actions](https://docs.github.com/en/actions) workflow and everything required to install an AWS VPC, EKS cluster and deploy the [Karpenter controller](https://karpenter.sh/docs/) along with a couple of karpenter EC2NodeClasses and Nodepools, each showcasing a different purpose.

> **NOTE:** _Sizing on any resource that has a cost is scaled down as much as possible, which also has an impact on High Availability of services but since HA has been taken into account everything else required to scale up is already in-place._

## Requirements
- AWS IAM credentials with enough permissions to create the AWS resources required (VPC, EKS, security-groups).
- A Github account with Github Actions enabled.
- A Github personal access token(PAT-classic) with the following permissions:
    - `admin:public_key`
    - `workflow`(also enables `repo`)

## Configure
### Variables and Secrets
In order to deploy a cluster with karpenter enabled you should fork this repository in your github account. Enable github actions and add the following secrets/variables:
- *variables*: **AWS_ACCOUNT_ID**
- *secrets*: **AWS_ACCESS_KEY_ID**
- *secrets*: **AWS_SECRET_ACCESS_KEY**
- *variables*: **AWS_REGION**
- *secret*: **GH_PAT_TOKEN** (The Github PersonalAccessToken mentioned in the requirements section).

> _Note1:_ On our production system we used our internal Hasicorp Vault for secrets instead of Github Secrets. Vault is a more appropriate tool for production use cases.

> _Note2:_ For this specific use case, we are using the AWS IAM account_id/secret combination to deploy the EKS cluster, but it would be preferable to create and use an IAM Role with the appropriate permissions instead.

> _Note3:_ Tofu will create IAM Roles that will be used for everything else. It will also create the `EKS_DEPLOY_ROLE` role. Anyone that wants to connect to this cluster should be able to assume that role. They will be connected as admins due to the configuration we have made in the Access Entries of our EKS cluster. It would be preferrable to create a different access entry/role for non-admin users that also need access.


## Deploy
We should make any configuration changes required (also check the `/karpenter-controller` and `karpenter-resources` folders). Now that we have everything in-place we are ready to deploy everything.
1. **Create a PR** to the default branch. The `Tofu-Plan` workflow will start and post the tofu plan output as a comment in your PR. If everything seems okay, move on to the next step.
2. **Merge the PR.** Upon merging the PR, the workflow will start the `Tofu-Apply` job of the  `.github/workflows/tf-workflow.yml` file. It will run `tofu apply`, create all resources and trigger the `karpenter-deploy.yml` workflow, which will run helm to deploy karpenter on our cluster and apply the yaml files to create the `EC2Nodeclass` and `Nodepool` resources of the `karpenter-resources/` folder.
3. **Done!** You have a cluster with karpenter enabled and 2 nodepools.

> _Note:_ The previous steps created the `generic` nodepool which will run any type of applications as we would usually deploy and a `runners` nodepool which has a very specific use case: create spot instances upon request of a gitlab-runner job starting and remove the nodes when they are not used anymore.

## Results
On our infrastructure we used 2 nodepools of the `generic` EC2NodeClass for various workloads and the `runner` nodepool for gitlab runners. All nodepools utilized SPOT instances.

**_The outcome was a 30% cost reduction on the `generic` workloads and an 80% cost reduction on our CI infrastructure._** Besides the obvious benefit of the cost reduction we also gained a few more benefits:
- Deploying or updating nodepools is very easy with kubernetes. The alternative of creating them with Terraform has had it's side effects.
- Setting the `max-pods` configuration parameter of an EKS nodegroup/nodepool becomes much easier as well as setting other EKS configuration parameters (`ENABLE_PREFIX_DELEGATION`, `WARM_PREFIX_TARGET`).
- Supports [Spot instance termination](https://karpenter.sh/docs/concepts/disruption/#interruption) natively.

## More notes, concerns and improvements

### Disclaimers
1. Prior to using karpenter, we did not have any type of node auto-scaling  in-place, which would have also helped but not as much.
2. This has been sourced from a private project and modified accordingly to use Github Actions and a scaled-down verison of anything that has a cost (NAT-GWs, VPN, EKS nodegroup).
3. The EKS module sets the `cluster_endpoint_public_access` to 'true'. In a full fleshed environment we would create our own github runner and have it running in our VPC, therefore removing the need for the endpoint public access.

## Improvements
1. Use Vault for secret management in all steps of workflow and on kubernetes cluster.
2. Remove public access of cluster API and add VPN that connects to VPC
3. `yaml` files contain environment variables which are tricky to replace with envsubst, so we need to find a better way
4. Replace Deployment of helm/yaml files with argoCD/flux
5. Documentation
