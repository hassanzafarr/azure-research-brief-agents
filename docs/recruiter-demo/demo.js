"use strict";

const examples = {
  azure: {
    question: "How can a portfolio app stay affordable on Azure?",
    sources: [
      {label: "Microsoft · Container Apps billing", url: "https://learn.microsoft.com/en-us/azure/container-apps/billing"},
      {label: "Microsoft · Container Registry pricing", url: "https://azure.microsoft.com/en-us/pricing/details/container-registry/"},
    ],
    stages: [
      {
        label: "Research notes",
        lead: "Review the platform's billing rules for the app and its image registry.",
        sections: [
          {title: "Container Apps Consumption", body: "Azure meters allocated CPU and memory while replicas run. A revision at zero replicas incurs no resource consumption charges."},
          {title: "Container Registry", body: "Azure prices Basic, Standard, and Premium registries per day. Registry pricing and Container Apps compute are separate."},
        ],
      },
      {
        label: "Critic review",
        lead: "The evidence covers two of the deployment's cost drivers. The draft needs to explain how both apply to a low-traffic portfolio.",
        sections: [
          {title: "Separate the costs", body: "Make clear which cost goes down with traffic and which continues while the registry exists."},
          {title: "Set the right expectation", body: "A public demo can wake when visited. Verify actual replica counts and review storage and logging as separate resources."},
        ],
      },
      {
        label: "Working draft",
        lead: "An Azure portfolio app has compute and supporting resource costs.",
        sections: [
          {title: "Compute", body: "Use the Consumption profile and a minimum of zero replicas."},
          {title: "Supporting services", body: "Review the registry's daily price, plus any storage or logs used by the project."},
          {title: "Recruiter access", body: "Provide a lightweight demo and link to the completed deployment for reviewers."},
        ],
      },
      {
        label: "Final brief",
        lead: "A low-traffic portfolio can run on demand. The main cost decision is which supporting resources to keep provisioned.",
        sections: [
          {title: "Let compute scale with visits", body: "Use Azure Container Apps Consumption with a minimum of zero replicas. Check the Replicas metric while the app is idle."},
          {title: "Account for standing resources", body: "The registry has a daily price. Include its cost alongside Blob Storage and logging when deciding whether to keep the deployment live."},
          {title: "Make the output easy to review", body: "A prepared brief gives recruiters a quick look at the app's output. Link the successful workflow run to show the Azure deployment."},
        ],
      },
    ],
  },
  oidc: {
    question: "How should GitHub Actions authenticate to Azure?",
    sources: [
      {label: "GitHub · OpenID Connect", url: "https://docs.github.com/en/actions/concepts/security/openid-connect"},
      {label: "Microsoft · Connect to Azure with OIDC", url: "https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect"},
    ],
    stages: [
      {
        label: "Research notes",
        lead: "Compare the GitHub token exchange with Azure's federated trust configuration.",
        sections: [
          {title: "GitHub token", body: "A workflow job with id-token: write can request an OIDC identity token describing its repository and execution context."},
          {title: "Azure federation", body: "Azure validates the issuer, audience, and subject against the federated credential before issuing an Azure access token."},
        ],
      },
      {
        label: "Critic review",
        lead: "The notes explain the token exchange. The audience also needs to know which jobs should be trusted and what access they receive.",
        sections: [
          {title: "Specify the trust scope", body: "Bind the credential to the repository and the main branch used for deployments."},
          {title: "Plan for long workflows", body: "Include when to obtain a fresh identity token if provisioning takes longer than the initial assertion's lifetime."},
        ],
      },
      {
        label: "Working draft",
        lead: "Grant token issuance to the deployment job and register a matching Azure federated identity.",
        sections: [
          {title: "Limit permissions", body: "Give the deployment identity access to the project resource group and Terraform state."},
          {title: "Run the deployment", body: "Sign in to Azure, provision resources with Terraform, and push the tested image to the registry."},
          {title: "Refresh credentials", body: "Repeat Azure login before the registry push if provisioning takes a while."},
        ],
      },
      {
        label: "Final brief",
        lead: "Use OpenID Connect to give the deployment job short-lived Azure credentials scoped to the project.",
        sections: [
          {title: "Bind trust to the deployment branch", body: "Match the GitHub token's subject in Azure and grant id-token: write to the deployment job. Check that the subject matches the repository's current format."},
          {title: "Scope the deployment identity", body: "Give the workflow access to the resources it provisions, its Terraform state, and the registry it pushes to. Give the running app a separate identity for image pulls."},
          {title: "Refresh after slow provisioning", body: "Request a fresh Azure login before the registry push so the job can exchange a valid assertion for registry access."},
        ],
      },
    ],
  },
};

const exampleSelect = document.querySelector("#example");
const playButton = document.querySelector("#play");
const stageButtons = Array.from(document.querySelectorAll("[data-stage]"));
const reportType = document.querySelector("#report-type");
const reportTitle = document.querySelector("#report-title");
const reportContent = document.querySelector("#report-content");
const announcement = document.querySelector("#announcement");
let playbackTimer;

function renderStage(stageIndex, announce = true) {
  const example = examples[exampleSelect.value];
  const stage = example.stages[stageIndex];

  reportType.textContent = stage.label;
  reportTitle.textContent = example.question;
  stageButtons.forEach((button, index) => {
    button.setAttribute("aria-pressed", String(index === stageIndex));
  });

  const lead = document.createElement("p");
  lead.className = "report-lead";
  lead.textContent = stage.lead;
  const content = document.createDocumentFragment();
  content.append(lead);

  for (const section of stage.sections) {
    const block = document.createElement("section");
    block.className = "report-section";
    const title = document.createElement("h3");
    title.textContent = section.title;
    const body = document.createElement("p");
    body.textContent = section.body;
    block.append(title, body);
    content.append(block);
  }

  const sources = document.createElement("section");
  sources.className = "sources";
  const sourcesTitle = document.createElement("h3");
  sourcesTitle.textContent = "Sources";
  const sourcesList = document.createElement("ul");
  for (const source of example.sources) {
    const link = document.createElement("a");
    link.href = source.url;
    link.textContent = source.label;
    const item = document.createElement("li");
    item.append(link);
    sourcesList.append(item);
  }
  sources.append(sourcesTitle, sourcesList);
  content.append(sources);
  reportContent.replaceChildren(content);
  if (announce) announcement.textContent = `Showing ${stage.label.toLowerCase()} for ${example.question}`;
}

function stopPlayback() {
  clearInterval(playbackTimer);
  playbackTimer = undefined;
  playButton.textContent = "Play walkthrough";
}

playButton.addEventListener("click", () => {
  if (playbackTimer !== undefined) {
    stopPlayback();
    return;
  }

  let stageIndex = 0;
  renderStage(stageIndex);
  playButton.textContent = "Stop walkthrough";
  playbackTimer = setInterval(() => {
    stageIndex += 1;
    renderStage(stageIndex);
    if (stageIndex === stageButtons.length - 1) stopPlayback();
  }, 1600);
});

exampleSelect.addEventListener("change", () => {
  stopPlayback();
  renderStage(stageButtons.length - 1);
});

for (const [index, button] of stageButtons.entries()) {
  button.addEventListener("click", () => {
    stopPlayback();
    renderStage(index);
  });
}

renderStage(stageButtons.length - 1, false);
