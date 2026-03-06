---
name: salaryman-skill
description: This skill should be used when working in the salary-man-setup repository to inspect, run, debug, or extend the Ubuntu bootstrap flow. Use it when another agent needs to drive setup.sh or the numbered install scripts, test the bootstrap on a local or remote machine, work through tmux, or update the managed shell/git/bootstrap configuration while preserving the repo's secret-handling guardrails.
---

# Salaryman Setup Driver

## Purpose

Drive the `salary-man-setup` repository as the source of truth for bootstrapping Ubuntu machines used for development, Linux administration, DevOps work, and AI-agent tooling.

Treat the repo as a numbered install pipeline plus a small set of tracked configs. Prefer running the repo's scripts over ad hoc package commands whenever the repo already has a supported path.

## Read First

Before making changes or running the flow, read these files in this order:

1. `../README.md`
2. `../setup.sh`
3. Any numbered scripts relevant to the requested task under `../scripts/`
4. If shell behavior is involved:
   - `../shell-config/.bashrc`
   - `../shell-config/.zshrc`
   - `../shell-config/.config/salary-man-shell/common.sh`
   - `../shell-config/.config/salary-man-shell/local.example.sh`
5. If commit safety or secret blocking is involved:
   - `../.githooks/pre-commit`
   - `../scripts/00-enable-repo-hooks.sh`
6. If Git/SSH behavior is involved:
   - `../git-config/.gitconfig`
   - `../scripts/06-install-git-ssh-config.sh`

## Core Operating Rules

Follow these repo-specific rules:

- Assume Ubuntu for the managed install flow.
- Use `../setup.sh` as the primary entrypoint for full or multi-step runs.
- Use individual numbered scripts only when the task is clearly partial or surgical.
- Keep new install sections as numbered scripts in `../scripts/NN-name.sh`.
- Make new or edited scripts print explicit verification lines like `tool_installed=yes|no`.
- Make scripts fail non-zero when verification fails.
- Update `../README.md` whenever the flow, repo layout, or script list changes.
- Keep secrets out of tracked files.
- Keep public-safe examples in tracked files such as `local.example.sh`.
- Keep machine-only or secret-bearing values in the user's local file: `~/.config/salary-man-shell/local.sh`.
- Do not add SSH key generation or SSH host scaffolding unless the user explicitly asks.
- Do not bypass the repo's secret guardrails unless the user explicitly asks for `--no-verify` behavior.

## Choosing the Right Execution Path

### Full bootstrap

Use the full flow when the user wants to set up a fresh box, validate the whole environment, or perform an end-to-end test.

Command pattern:

```bash
cd ../
./setup.sh
```

### Partial rerun

Use selected scripts when only one part of the stack needs to change.

Examples:

```bash
cd ../
./setup.sh 04-install-cli-tools.sh 05-install-shell-config.sh
```

```bash
cd ../
./scripts/07-install-ai-agents.sh
```

### Repo hook enablement

Use this after cloning a new copy of the repo, before making commits in that clone.

```bash
cd ../
./scripts/00-enable-repo-hooks.sh
```

## Remote and tmux Workflow

When driving a remote server or a long-running install, prefer tmux.

### Standard pattern

1. Check whether the tmux session already exists.
2. Reuse the existing session if present.
3. Clone or update the repo on the target machine.
4. Run `./setup.sh` or the selected scripts.
5. Capture pane output instead of assuming success.
6. Read the summary file under `logs/setup-<timestamp>/summary.txt`.

### Useful tmux commands

Create or reuse a session:

```bash
tmux has-session -t ai-setup 2>/dev/null || tmux new-session -d -s ai-setup
```

Run the setup in the first pane:

```bash
tmux send-keys -t ai-setup:0.0 'git clone https://github.com/alchemiststudiosDOTai/salary-man-setup.git ~/salary-man-setup || { cd ~/salary-man-setup && git pull --ff-only; }; cd ~/salary-man-setup && ./setup.sh' Enter
```

Capture recent output:

```bash
tmux capture-pane -t ai-setup:0.0 -p -S -120
```

Read the summary after completion:

```bash
cat ~/salary-man-setup/logs/setup-<timestamp>/summary.txt
```

## Validation Workflow After Editing the Repo

After editing scripts or tracked config, run this checklist before committing:

1. Run `bash -n` on every changed shell script.
2. Run a working-tree secret scan.
3. Ensure the repo-local hooks are enabled in the current clone.
4. Review the staged diff for accidental secrets or machine-specific paths.
5. Commit only after the secret guardrail passes.

Recommended commands:

```bash
bash -n ../setup.sh
bash -n ../scripts/00-enable-repo-hooks.sh
bash -n ../scripts/04-install-cli-tools.sh
```

```bash
cd ../
gitleaks detect --source . --no-git --redact --exit-code 0
```

```bash
cd ../
./scripts/00-enable-repo-hooks.sh
```

## Secret-Handling Policy

Treat secret hygiene as part of the workflow, not as cleanup.

- Never copy real API keys from a live shell rc into tracked files.
- Use placeholder values such as `<set-local-token>` in tracked examples.
- Keep real provider wrappers only in `~/.config/salary-man-shell/local.sh` on the target machine.
- Use the tracked pre-commit hook in `../.githooks/pre-commit` to block suspicious staged content.
- If the hook flags something, stop and inspect before proceeding.

## Repo-Specific Paths

Use these paths as anchors when navigating the repo:

- Main driver: `../setup.sh`
- Numbered scripts: `../scripts/`
- Shell config: `../shell-config/`
- Git config: `../git-config/`
- Secret guardrails: `../.githooks/pre-commit`
- Saved Neovim config: `../nvim-config/`
- Run logs: `../logs/`

## Success Criteria

Consider a run successful only when all of the following are true:

- The requested scripts finish without non-zero exit status.
- The relevant verification lines report `yes`.
- `setup.sh` writes a summary file with `PASS` for each executed script.
- No secret scan findings appear in the repo history or working tree for the current change.
- Any README or tracked config changes needed by the new behavior are included.

## When to Update This Skill

Update this skill whenever:

- a new numbered setup script is added
- script order changes
- secret-handling policy changes
- shell config layout changes
- the preferred tmux or remote execution flow changes
- the repo gains new required validation steps
