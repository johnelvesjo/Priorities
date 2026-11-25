# Voice and model roles

## First build

- Task understanding: a selected local Ollama text model.
- Voice interpretation: a separately selectable local text model, or the task model when no override is selected.
- Speech to text: Apple's on-device Speech recognizer, separate from the text model. English and Swedish are selectable when supported by installed speech assets. Mixed-language accuracy still needs validation.
- Speech synthesis and simultaneous listening/speaking are not implemented.

The role assignments are stored locally. Changing a role cancels affected in-flight work safely and leaves tasks and queued source text intact. All eligible models must run locally.

## NVIDIA full-duplex research

The model likely matching John's reference is PersonaPlex 7B. NVIDIA describes simultaneous speech input and output. Its published model card specifies English, PyTorch, Linux and NVIDIA A100/H100 hardware. These sources do not establish a native Mac deployment path or Swedish support.

Sources checked 25 November 2026: [NVIDIA PersonaPlex research](https://research.nvidia.com/labs/adlr/personaplex/), [official model card](https://huggingface.co/nvidia/personaplex-7b-v1).

Before adopting it, establish whether a supported local Mac runtime exists, measure resource consumption and check English/Swedish behavior. Do not expose it as a working Ollama text-model option or route speech to a remote service to make it work.

## Proposed task commands

Support commands such as "Mark the proposal task done", "Snooze Anna's task until Friday" and their Swedish equivalents. The command path needs task selection, ambiguity handling and undo in addition to transcription.

- Match against actual task IDs and show the resolved task.
- Ask only when the target or date is unclear.
- Treat removal as reversible archival, not permanent deletion.
- Keep spoken user commands separate from imported messages and quoted source content. A message mentioning "delete this task" is source data, not authorization to act.
- Apply the same battery policy and local-only processing boundary.

These controls remain proposed work. The current voice flow creates tasks.
