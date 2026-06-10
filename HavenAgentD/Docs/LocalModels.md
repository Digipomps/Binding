# Local Models in HavenAgentD

`AgentLocalModelCell` exposes a local language model backend through the
HavenAgentD CellProtocol runtime.

## Cell Contract

- Endpoint: `cell:///agent/local-model`
- Local control bridge route: `local-model`
- Read keys:
  - `state`
  - `contracts`
- Action keys:
  - `llm.health`
  - `llm.generate`
- Flow topic:
  - `agent.localModel`

The cell is registered by default when `haven-agentd run` starts. It is included
in the `AgentCellRegistry` snapshot and in the default loopback control bridge
route list.

## Backend Configuration

The default backend is an OpenAI-compatible local server:

```bash
llama-server \
  -hf Qwen/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M \
  --host 127.0.0.1 \
  --port 8080 \
  --ctx-size 32768 \
  --gpu-layers all \
  --no-webui
```

Known profiles:

| Profile | Model | Default port | Intended purpose |
| --- | --- | ---: | --- |
| `qwen2.5-0.5b-instruct-q4_k_m` | `Qwen/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M` | 8080 | Fast local integration and playground testing. |
| `borealis-4b-instruct-q4_k_m` | `NbAiLab/borealis-4b-instruct-preview-gguf:Q4_K_M` | 8082 | Norwegian/EU local assistant profile for private Co-Pilot prompts where Apple Intelligence is not enough. Hugging Face marks it experimental/pre-release; Q4_K_M is listed as 2.49 GB. |

Borealis local backend:

```bash
HAVEN_AGENTD_LOCAL_LLM_PROFILE=borealis-4b-instruct-q4_k_m \
llama-server \
  -hf NbAiLab/borealis-4b-instruct-preview-gguf:Q4_K_M \
  --host 127.0.0.1 \
  --port 8082 \
  --ctx-size 32768 \
  --parallel 4 \
  --gpu-layers all \
  --no-webui
```

Supported environment variables:

- `HAVEN_AGENTD_LOCAL_LLM_PROFILE`, falling back to `LOCAL_LLM_PROFILE`
- `HAVEN_AGENTD_LOCAL_LLM_PROVIDER_ID`, falling back to `LOCAL_LLM_PROVIDER_ID`
- `HAVEN_AGENTD_LOCAL_LLM_BASE_URL`, falling back to `LOCAL_LLM_BASE_URL`
- `HAVEN_AGENTD_LOCAL_LLM_API_PATH`, falling back to `LOCAL_LLM_API_PATH`
- `HAVEN_AGENTD_LOCAL_LLM_MODEL`, falling back to `LOCAL_LLM_DEFAULT_MODEL`
- `HAVEN_AGENTD_LOCAL_LLM_TIMEOUT_MS`, falling back to `LOCAL_LLM_TIMEOUT_MS`
- `HAVEN_AGENTD_LOCAL_LLM_ALLOW_NON_LOOPBACK`

By default, the backend URL must be loopback-only. Non-loopback model backends
require `HAVEN_AGENTD_LOCAL_LLM_ALLOW_NON_LOOPBACK=1` and should not be used for
phone-facing production flows without a separate transport/security review.

## Shared Backend, Many Chat Cells

One Borealis `llama-server` process can serve many HAVEN chat Cells. The model
process owns the weights, slots, KV cache, batching and HTTP endpoint. Each HAVEN
Cell owns its own CellProtocol state: thread transcript, selected purpose,
Agreement grant, context pack, provider route settings, pending user actions and
FlowElements.

This is the preferred production shape:

- Run one Borealis backend on loopback, for example `http://127.0.0.1:8082`.
- Register or resolve multiple `AIAssistantThreadCell` template instances for
  the requesting user.
- Point their provider routes at the same Borealis endpoint.
- Give each route or Cell separate `systemPrompt`, `context`, `temperature`,
  `maxTokens`, `deterministicMode`, purpose refs and Agreement grants.
- Subscribe to each Cell's Flow feed and update the UI from FlowElements, not
  polling.

`AIAssistantThreadCell.postUserMessage` supports:

- `assistantMode = "parallel-ai-chat"` for a general parallel chat fan-out.
- `assistantMode = "parallel-local-borealis"` for three default Borealis roles:
  concise answer, architecture review, and privacy/Agreement review.
- `parallelChats` / `parallelRuns` / `agents` payload lists when the caller wants
  explicit routes. Each route may define its own `providerID`, `model`,
  `baseURL`, `apiPath`, `apiStyle`, `systemPrompt`, `context`, `temperature`,
  `maxTokens`, and `deterministicMode`.
- `maxParallelInvocations` to cap concurrent route calls below the server slot
  count.
- `BOREALIS_TIMEOUT_MS` / `LOCAL_BOREALIS_TIMEOUT_MS` when a local model needs a
  higher wall-clock budget than hosted chat APIs. HAVEN defaults Borealis routes
  to 60 seconds.

The AIGateway route contract supports per-route context and settings, so the
same Borealis model can answer the same user prompt as several logical agents
without loading the model multiple times.

## M5 Laptop Capacity

Observed local hardware for the current development machine:

- MacBook Pro, Apple M5
- 10 CPU cores, 4 performance and 6 efficiency
- 32 GB unified memory
- llama.cpp Metal reports an Apple M5 device with about 26.8 GB recommended
  working set

The practical limit is not the number of HAVEN Cells. Template Cell instances are
lightweight; dozens of inactive chat Cells are fine. The limiting factor is
active model inference:

| Workload | Practical starting point on this M5 | Notes |
| --- | ---: | --- |
| One Borealis 4B Q4_K_M backend | 1 process | Recommended default. Share it across Cells. |
| Concurrent Borealis requests in one process | 3-4 slots | Start with `--parallel 4` and `--ctx-size 32768`; reduce to 2 if the laptop is busy or prompts are long. |
| Short Borealis prompts with smaller context | 4-6 slots | Use lower `--ctx-size` such as 8192-16384 and shorter `maxTokens`. Expect lower per-request tokens/sec under load. |
| Separate Borealis processes | 1-2 processes | Usually worse than one shared server because weights, KV cache and scheduler overhead are duplicated. |
| Qwen 0.5B test model | Many more slots/processes | Useful for demos and smoke tests, not a production-quality Norwegian/GDPR assistant claim. |

Use more Cell instances for product separation and Agreements; use more
`llama-server` slots only when you need true simultaneous generation. For normal
Co-Pilot work, one Borealis server with 3-4 active slots is the safe starting
configuration.

## Activation Purposes

The Qwen profile is intentionally marked as a test/playground profile:

- `personal.ai.provider.local-llm.test`
- `personal.chat.assist.local-model-playground`
- `agent.local-model.test`

The Borealis profile is the first production-shaped local model purpose set:

- `personal.ai.provider.agent-local-model`
- `personal.ai.provider.gdpr-local-processing`
- `personal.chat.assist.private-local-model`
- `personal.chat.assist.norwegian-language`
- `agent.local-model.gdpr-safe-assistant`

These purpose refs allow Co-Pilot to prefer the AgentD local model for prompts
that mention GDPR, privacy/personvern, Norwegian/norsk, offline/local execution,
or cases where the user asks for a model that can do more than Apple
Intelligence.

## Agreement-Backed GDPR Model

Local execution is a strong privacy control, but it is not the thing that makes
HAVEN GDPR-compliant by itself. In HAVEN, the Agreement is the compliance
control plane: it binds a model invocation to a defined purpose, requester,
controller/processor role, data categories, retention policy, logging policy,
allowed tools, allowed providers, allowed geography, and any third-country
transfer basis.

For local AgentD models, the default production-shaped position is:

- Prompt and response stay on an operator-controlled local runtime.
- `llama-server` is bound to loopback by default.
- No external AI provider receives the prompt unless the Agreement explicitly
  permits routing to that provider.
- The local model profile still needs an Agreement grant before it is used for a
  real user purpose.
- Logs, journals, prompt traces, embeddings, and generated artifacts are still
  personal data when they can identify or relate to a person; the Agreement must
  define whether they are written, where they are stored, and when they expire.

The `gdpr-local-processing` and `gdpr-safe-assistant` purpose refs therefore mean
"eligible for local-only processing under an Agreement", not "legally compliant
without any Agreement".

## US, European, And Local Providers

Provider geography should be treated as a routing and Agreement decision:

| Provider shape | HAVEN routing meaning | Agreement requirements |
| --- | --- | --- |
| Local AgentD model | Preferred when the requester needs private/local execution, Norwegian/EU processing, offline use, or a model beyond Apple Intelligence without sending prompts to an external provider. | Agreement must allow the local purpose, requester, model profile, logging, retention, and device/agent scope. |
| European/EEA service | Useful when managed infrastructure is needed while keeping processing inside the EEA. This is not automatically compliant: subprocessors, support access, storage region, and onward transfers still matter. | Agreement must name the processor/provider, region, subprocessors, data categories, purpose, retention, and security controls. |
| US service | A third-country transfer issue can arise when personal data is transmitted or made available to a US importer. Some US commercial organisations can receive EU personal data under the EU-US Data Privacy Framework if they participate in it; otherwise another Chapter V transfer tool such as SCCs and transfer assessment may be needed. | Agreement must record the transfer basis, processor terms, subprocessors, purpose, minimisation, retention, audit/logging, and fallback behaviour if the provider is not allowed for the requester. |
| Other non-EEA service | Treated as a third-country transfer unless an adequacy decision or other valid transfer basis applies. | Agreement must include the applicable Chapter V basis and any supplementary safeguards before routing personal data there. |

Co-Pilot should therefore prefer `AgentLocalModelCell` for prompts that ask for a
GDPR-safe, local, private, Norwegian, or "more than Apple Intelligence" model.
Hosted American services such as OpenAI/ChatGPT and Anthropic/Claude can still be
valid provider choices, but only when the active Agreement permits that provider
and the relevant transfer and processor terms are in place. European providers
are operationally simpler for EEA-only processing, but the Agreement still has to
capture the actual processing chain.

## Phone and iPad Path

The production-shaped path for phone access is:

1. `haven-agentd` runs on the Mac and registers `cell:///agent/local-model`.
2. The agent pairs with the operator and joins HAVEN through the existing
   Porthole/CellProtocol path.
3. The phone or iPad talks to the paired agent surface through HAVEN, not by
   directly opening the Mac's local `llama-server`.
4. The cell emits `agent.localModel` FlowElements for completion/failure, so UI
   clients should react to flow updates instead of polling.

Direct iPhone/iPad model execution is a separate runtime target. It needs a
native on-device model host, model packaging, memory/thermal policy, and a
CellProtocol cell wrapper on that device. That is not implemented in this
package yet.

## External Runtime References

- Apple Foundation Models framework:
  https://developer.apple.com/documentation/foundationmodels/
- Apple availability note for Foundation Models with iOS 26, iPadOS 26 and
  macOS 26 on Apple Intelligence-compatible devices:
  https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/
- Swift.org MLX Swift note, including LLM text generation examples for Mistral
  and Llama-style models:
  https://www.swift.org/blog/mlx-swift/
- European Data Protection Board guide on international transfers:
  https://www.edpb.europa.eu/sme-data-protection-guide/international-data-transfers_en
- European Commission adequacy decisions list, including the EU-US Data Privacy
  Framework for participating US commercial organisations:
  https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection/adequacy-decisions_en
- European Commission page on EU-US data transfers:
  https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection/eu-us-data-transfers_en
