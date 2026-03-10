# salary-man-setup

Personal setup repo for rebuilding my working environment when I move to a new machine, server, WSL instance, or remote box.

## Purpose

This repo is for **my own repeatable setup**.

It is the place where I keep the install scripts, config copies, and bootstrap flow for the stack I use as a:

- developer
- Linux/sysadmin
- infra/devops engineer

Instead of rebuilding my environment from memory every time, I keep the steps here and rerun them on a fresh system.

## Assumptions

- target OS is **Linux**
- scripts assume **Ubuntu**
- scripts are meant to be run in order
- the full setup will be driven by **one main driver script** that runs each script sequentially

## Repo layout

```text
salary-man-setup/
├── .githooks/                      # repo-local git hooks, including secret leak guardrails
├── nvim-config/                    # saved copy of my Neovim config
├── scripts/
│   ├── 00-enable-repo-hooks.sh    # enable tracked repo hooks for this clone
│   ├── 01-build-neovim.sh         # build/install Neovim from source, restore config, verify install
│   ├── 02-install-devops-sysadmin-tools.sh
│   │                                # install devops/sysadmin toolchain
│   ├── 03-install-web-dev-stack.sh # install Python, Node/TS/Biome, Rust, uv, ruff
│   ├── 04-install-cli-tools.sh    # install terminal-first CLI utilities
│   ├── 05-install-shell-config.sh # install managed bash/zsh/starship shell config
│   ├── 06-install-git-ssh-config.sh # install managed git config and normalize existing ssh perms
│   └── 07-install-ai-agents.sh    # install AI agent CLIs via uv
├── shell-config/                  # managed shell dotfiles/templates
├── git-config/                    # managed git config templates
├── salaryman-skill/               # local skill for another agent to drive this repo safely
├── install.sh                     # curlable bootstrap script: clone/update repo then run setup.sh
├── setup.sh                       # main driver that runs scripts sequentially
└── README.md
```

## Script structure

Each script is one install section for a part of my stack.

Examples:
- editor setup
- shell setup
- dev tools
- infra/devops tools
- containers and Kubernetes tooling
- database clients and local services
- workstation quality-of-life tools

The intent is to keep each section isolated so I can rerun only what I need.

## Current scripts

### `scripts/01-build-neovim.sh`

Builds and installs Neovim from source, saves/restores my config, and verifies:

- whether the `nvim` binary is installed
- whether the config loads cleanly

### `scripts/02-install-devops-sysadmin-tools.sh`

Installs my Linux infra / devops baseline, including tools such as:

- Docker
- kubectl
- Helm
- k9s
- kind
- Terraform
- PostgreSQL client tools
- Ansible
- common Linux admin/network/debugging tools

### `scripts/03-install-web-dev-stack.sh`

Installs my web/dev language stack, including:

- Python 3
- Node.js
- TypeScript
- Biome
- Rust
- Astral `uv`
- `ruff`

### `scripts/00-enable-repo-hooks.sh`

Enables tracked repo-local git hooks for the current clone.

Current behavior:

- configures `core.hooksPath` to `.githooks`
- enables the tracked pre-commit hook
- makes secret leak checks run before each commit

### `scripts/04-install-cli-tools.sh`

Installs my terminal-first CLI baseline, including tools such as:

- GitHub CLI
- tmux
- ripgrep
- fd
- fzf
- bat
- eza
- zoxide
- git-delta
- gitleaks
- lazygit
- starship
- httpie
- hyperfine
- mosh
- direnv
- btop
- shellcheck
- tea
- tea

### `scripts/05-install-shell-config.sh`

Installs my managed shell setup, including:

- repo-managed `.bashrc`
- repo-managed `.zshrc`
- common shell aliases/functions
- redacted `local.example.sh` with extra aliases/functions from my old bashrc
- starship config
- zoxide/direnv shell init
- local override file for machine-specific additions and secrets

### `scripts/06-install-git-ssh-config.sh`

Installs my managed Git config and handles SSH conservatively:

- repo-managed `.gitconfig`
- no SSH key generation
- no SSH host/config scaffolding
- normalizes permissions on an existing `~/.ssh` directory if one is already there

### `scripts/07-install-ai-agents.sh`

Installs AI agent tooling at the end of the flow.

Current behavior:

- installs `tunacode-cli` with `uv tool install --force tunacode-cli`
- installs `opencode` via `curl -fsSL https://opencode.ai/install | bash`
- installs `@mariozechner/pi-coding-agent` globally with npm
- installs `coderabbit` via `curl -fsSL https://cli.coderabbit.ai/install.sh | sh`
- installs `@openai/codex` globally with npm

## Local skill

### `salaryman-skill/SKILL.md`

Provides a local skill for another agent to operate inside this repo.

Current behavior:

- explains how to read the repo before making changes
- describes when to use `setup.sh` versus individual numbered scripts
- documents the tmux/remote execution pattern used to test this repo
- reinforces secret-handling rules and the repo-local pre-commit guardrail

## Execution model

The scripts are intended to be run **sequentially** by a single top-level driver script.

Bootstrap from a fresh machine with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/alchemiststudiosDOTai/salary-man-setup/main/install.sh | bash
```

Run only selected setup sections through the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/alchemiststudiosDOTai/salary-man-setup/main/install.sh | bash -s -- 04-install-cli-tools.sh 05-install-shell-config.sh
```

Clone/update the repo without running setup yet:

```bash
curl -fsSL https://raw.githubusercontent.com/alchemiststudiosDOTai/salary-man-setup/main/install.sh | bash -s -- --skip-run
```

If you are running from a root shell, set `TARGET_USER` so user-scoped files do not get installed into `/root`.

Default flow from an existing clone:

```bash
./setup.sh
```

List scripts:

```bash
./setup.sh --list
```

Run only selected scripts:

```bash
./setup.sh 04-install-cli-tools.sh 05-install-shell-config.sh
```

The driver script runs numbered scripts in order, stops on first failure, and writes logs under `./logs/`.

## Notes

- this repo is optimized for **my workflow**, not as a generic public bootstrap project
- scripts may install both developer and admin tooling on the same machine
- verification output is preferred where possible so each script can clearly report success/failure
