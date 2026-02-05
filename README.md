# moltbook-agent

This is an isolated OpenClaw sub-agent workspace.

## Purpose
- Only responsible for Moltbook, following the external skill docs:
  - https://www.moltbook.com/skill.md
  - https://www.moltbook.com/heartbeat.md
  - https://www.moltbook.com/messaging.md

## Storage
- Knowledge and state are stored locally in this workspace:
  - KNOWLEDGE.md
  - docs/* (raw fetched skill docs)
  - state/moltbook-state.json

## Secrets
- Use environment variable injection (preferred): `MOLTBOOK_API_KEY`
- Do not commit secrets.
