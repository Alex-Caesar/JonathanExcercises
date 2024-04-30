# Exercise 2
Deploy GitLab Enterprise through helm (its free). All infra resources must be deployed through Terraform. The GitLab instance must have the following configuration:
- Deployed into a AKS cluster
- Connect to a external PSQL database with a private endpoint
- Store gitlab and PSQL credentials in AKV
- Web portal access should be through AppGW as the ingress controller for AKS with a self-signed cert generated and stored in AKV

**Note:** The Gitlab helm chart can be deployed through Terraform or through CLI. Your preference. You should not need to modify much of the helm char default values outside of the TLS cert and DB.

## Extra Credit
- Store gitlab images in an ACR (with a private endpoint) and create a cache rule to fetch public images
- Helm chart should reference the private ACR registry created above. Note: AKS cluster should have pull acces on the ACR to pull images.
- Integrate GitLab with Azure AD for SSO/SAML.

## Resources
- GitLab helm chart: https://docs.gitlab.com/charts/installation/deployment.html
- AKS integrations with AppGW https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#ingress_application_gateway
