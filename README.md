## Workflow and PAT(private-access-token)
To be able to save secrets from within the worflow itself, we needed to create an extra token (PAT) and save it manually to our gh action secrets.

> Warning: The EKS module sets the `cluster_endpoint_public_access` to 'true'. In a full fleshed environment we would create our own github runner and have it running in our VPC, therefore removing the need for the endpoint public access.

> Warning:

> Improvements: yaml files contain environment variables which are tricky to replace with envsubst, so we need to find a better way
