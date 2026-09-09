# yolo-tools

Curl-installable single-file shell utilities. No runtime, no package manager,
no dependencies beyond `bash` and `curl`. Two tools today: `barkme.sh` sends
an iOS push notification from a script, `purgeb.sh` reclaims disk from build
artifact directories.

## Install

### Interactive install (recommended)

```bash
# Interactive tool selection
bash <(curl -fsSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh)
```

```bash
# Force reinstall with interaction
bash <(curl -fsSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh) --force
```

### One-liner install
```bash
# Install every tool, no prompts
curl -sSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh | bash
```

`install.sh -v <tag>` pins a release, but this repo has no tags yet, so `-v`
resolves to a 404. Until it does, installs track `main`. Each tool carries its
own `# Version:` line and the installer prints upgrades and reinstalls, so you
can see what you got.

## Tools

The installer discovers whatever is in `src/bin/`, and the non-interactive
one-liner installs all of it. Today that is both of these:

- **barkme.sh** — Bark client for iOS push notifications
- **purgeb.sh** — deletes build artifact directories (`node_modules`, Rust
  `target`, and friends) under a path you name. Dry-run first: `purgeb.sh -n <path>`.

## `barkme.sh`

[Bark](https://bark.day.app/) is a simple iOS notification service that allows you to send notifications to your devices.

- Docs: https://bark.day.app/

```bash
# Setup
export BARK_KEY="your_device_key"
export BARK_SERVER="your_bark_server" # or use the official default: "https://api.day.app"

# Send notification
barkme.sh "Hello World"
```

### Claude Code Hook Example

```sh
# ~/.claude/settings.json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "barkme.sh -t \"Claude Code Notify\" -g \"Claude Code\" -l \"active\" -i \"https://avatars.githubusercontent.com/in/1452392\" \"$(jq -r '.message')\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "barkme.sh -t \"Claude Code\" -g \"Claude Code\" -i \"https://avatars.githubusercontent.com/in/1452392\" \"task stop\""
          }
        ]
      }
    ]
  }
}
```

## `purgeb.sh`

Reclaims disk from build artifact directories, recursively, with a confirmation
step. Bash 3.2+, so it works on stock macOS.

A root path is required — it will not guess, and it will not run against `$PWD`
by accident.

```bash
purgeb.sh -n ~/src              # dry run: what would go, and how much space
purgeb.sh ~/src                 # delete node_modules, asking first
purgeb.sh --rust ~/src          # node_modules + Rust target/
purgeb.sh -e "*/infra/*" ~/src  # keep anything matching a glob
purgeb.sh -y ~/src              # no prompt
```

`purgeb.sh --help` lists every flag.
