# yolo-tools

Collection of utility scripts and tools.

## Install

### Interactive install (recommended)

```bash
# Interactive tool selection
bash <(curl -fsSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh)
```

```bash
# Force reinstall with interaction
bash <(curl -fsSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh) --force

# Install specific version
bash <(curl -fsSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh) -v v1.0.0
```

### One-liner install
```bash
# Install all tools (no interaction)
curl -sSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh | bash

# With version
curl -sSL https://raw.githubusercontent.com/thevibeworks/yolo-tools/main/install.sh | bash -s -- -v v1.0.0
```

## Tools

- **barkme.sh** - Bark notification service client for iOS push notifications

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
