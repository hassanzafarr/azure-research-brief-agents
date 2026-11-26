# Research Brief Generator demo

**Example question:** How can a portfolio app stay affordable on Azure?

This prepared example illustrates the four-agent LangGraph workflow. Expand any stage to see what it contributes.

<details>
<summary><strong>Researcher · Collect evidence</strong></summary>

Azure Container Apps Consumption meters allocated compute while replicas run. A revision at zero replicas incurs no compute charges. Azure Container Registry publishes a separate daily price for each registry tier.

</details>

<details>
<summary><strong>Critic · Review coverage</strong></summary>

The brief should distinguish app compute from the registry's daily charge. It should also account for storage and logs, and explain how public traffic can start a replica.

</details>

<details>
<summary><strong>Writer · Draft recommendations</strong></summary>

Use the Consumption profile with a minimum of zero replicas. Measure the actual replica count when the app is idle, and review the daily registry rate alongside logging and storage.

</details>

<details open>
<summary><strong>Editor · Read the final brief</strong></summary>

**Let compute scale with traffic.** Set Azure Container Apps to a minimum of zero replicas and check the Replicas metric during idle periods.

**Price supporting resources separately.** Include the registry, Blob Storage, and logging when comparing the cost of keeping the Azure deployment online.

**Make the demo easy to review.** Share a prepared brief recruiters can read immediately and include the successful GitHub Actions run as evidence of the Azure deployment.

</details>

[Container Apps billing](https://learn.microsoft.com/en-us/azure/container-apps/billing) · [Azure Container Registry pricing](https://azure.microsoft.com/en-us/pricing/details/container-registry/)

## Deployment evidence

The original Streamlit app was packaged with Docker, tested in a temporary Kubernetes cluster with kind, then deployed to Azure Container Apps through GitHub Actions and Terraform. GitHub authenticated to Azure through OIDC.

[Passing Azure deployment run](https://github.com/hassanzafarr/azure-research-brief-agents/actions/runs/45845007114) · [Deployment architecture](../azure-deployment.md)
