# Karpenter
Karpenter is an open-source cluster autoscaler that automatically provisions new nodes in response to unschedulable pods. Karpenter evaluates the aggregate resource requirements of the pending pods and chooses the optimal instance type to run them. It will automatically scale-in or terminate instances that don’t have any non-daemonset pods to reduce waste. It also supports a consolidation feature which will actively move pods around and either delete or replace nodes with cheaper versions to reduce cluster cost.


## Install/Upgrade Karpenter Controller
---
> **&#9432;** **INFO**

The karpenter controller is the only workload that *can not* run on nodes created by karpenter. Thus, we have created a single nodegroup with specific taints/labels so that we can configure karpenter to run on the *karpenter* nodegroup.
Configuration for running on that nodepool has been configured in the `values.yaml` file.

---


```
docker logout public.ecr.aws
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
    --namespace "karpenter" --create-namespace \
    --version "0.36.0" \
    -f values.yaml \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="<karpenter-controller-role-arn>" \
    --set settings.clusterName=<eks-cluster-name> \
    --set settings.clusterEndpoint='<eks-cluster-endpoint>' \
    --set settings.interruptionQueue="<karpenter-sqs-queue-name>"
```

## Install NodeClasses and NodePools
Once karpenter is up and running, we need to create NodeClasses and Nodepools to actually create nodes.

## Monitoring
Add the following scrape config to prometheus configuration.

```
extraScrapeConfigs: |
    - job_name: karpenter
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - karpenter
      relabel_configs:
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        regex: http-metrics
        action: keep
```

The following 2 files in this folder are Grafana Dashboards for karpenter that should be imported.
- `grafana-karpenter-capacity-dashboard.json`
- `grafana-karpenter-performance-dashboard.json`

---
---
## Configuration options
Below we explain why we have used some of the options that we did and what problem we tried to solve.

### Solve Jira issue [OPS-470](https://avlos.atlassian.net/browse/OPS-470) with:
1. The EC2NodeClass discovers subnets through ids or tags. When launching nodes, a subnet is automatically chosen that matches the desired zone. If multiple subnets exist for a zone, the one with the most available IP addresses will be used. What we did as a preparation step is to add 3 more private subnets to our AWS VPC with more IP addresses (/22 instead of /24) and add the karpenter tag to all of these subnets. Since karpenter will detect that the new subnets have more IP addresses it will select the new subnets.

2. By setting the `ENABLE_PREFIX_DELEGATION=true` and the `WARM_PREFIX_TARGET=1` environment variables through the `userData` field of the EC2NodeClass. Those 2 parameters will enable **VPC CNI Prefix Assignment Mode**[[1]](https://aws.amazon.com/blogs/containers/amazon-vpc-cni-increases-pods-per-node-limits/)&[[2]](https://aws.github.io/aws-eks-best-practices/networking/prefix-mode/index_linux/#prefix-mode-for-linux)

### Karpenter Pod Density
Set max-pods for small nodes that require an increased pod density: `.spec.template.spec.kubelet.maxPods: 110`
This setting, along with the prefix assignment mode will allow an increased amount of pods on each kubernetes node. We set it to the suggested maximum of 110 for all nodes and all instance types.

### Interruption handling
If interruption-handling is enabled, Karpenter will watch for upcoming involuntary interruption events that would cause disruption to your workloads. These interruption events include:

- Spot Interruption Warnings
- Scheduled Change Health Events (Maintenance Events)
- Instance Terminating Events
- Instance Stopping Events

For Spot interruptions, the NodePool will start a new node as soon as it sees the Spot interruption warning. Spot interruptions have a 2 minute notice before Amazon EC2 reclaims the instance. Karpenter’s average node startup time means that, generally, there is sufficient time for the new node to become ready and to move the pods to the new node before the NodeClaim is reclaimed. Karpenter enables this feature by watching an SQS queue which receives critical events from AWS services which may affect your nodes. This SQS queue has been created with Terraform (along with the Health rules/targets) and is configured when deploying to Karpenter(helm) with the `interruptionQueue` parameter set to the name of the SQS queue.

### Drift Controller
The drift controller, if enabled, will check for inconsistencies between the nodepool/nodeclass configurations and the deployed nodepool/nodeclass configurations. If, for example, we have specified different instance types for a nodepool, the drift controller will start the disruption process to make nodeclaims match the new instance types, replacing the nodes in the process. More info on the **Drift** controller can be found [here.](https://karpenter.sh/docs/concepts/disruption/#drift)

### Instance type selection
For our staging cluster (`avlos-stg`) we have decided to use the following AWS instance type families: `"t", "m", "r", "c"`. For production clusters it would be better to avoid using the `t` family, at least for critical workloads. These can be updated at any time.
