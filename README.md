<img width="600" height="240" alt="Jul 14, 2026, 01_13_17 AM" src="https://github.com/user-attachments/assets/b6ec762b-d3dc-4b06-9f54-ceb5e78a7910" />

# tchat

tchat is a lightweight terminal app that lets you chat with AI models using your own API keys.

I created it to be fast, simple, and usable from a terminal without needing a full desktop app. It can be used for everyday conversations, coding, debugging, working with files, and running approved terminal commands.

It was primarily built for Termux on Android, but it is designed to work in other Bash-based terminal environments as well.

Every feature, idea, design decision, improvement, and bug fix was planned and directed by me. AI was used as a coding assistant during development, while I handled the overall architecture, testing, debugging, and refinement of the project.

## Features

* Supports multiple AI providers
* Lets you use your own API keys
* Or sign in with your existing Gemini CLI, Claude Code, or Codex CLI account (no API key needed)
* Switch between different models
* Search and browse available models
* Create, read, and manage files
* Run terminal commands with confirmation
* Save conversations
* Customize colors and appearance
* Save a default model
* Optional persistent memory
* Lightweight and easy to run

## Supported providers

* OpenRouter
* Google Gemini
* Anthropic
* OpenAI

## Connection modes

For Gemini, Anthropic, and OpenAI you can connect in two ways:

* **API key**: full features, including file tools and approved terminal commands.
* **Account login**: uses the provider's official CLI (`gemini`, `claude`, or `codex`) and your existing subscription. This mode is read-only: the AI can't write files or run commands through tchat.

On Termux, OpenAI account login runs Codex inside an Ubuntu PRoot container. tchat can set this up for you automatically.

Switch modes at any time with `/auth`.

## Requirements

You need:

* Bash
* curl
* jq

On Termux, install them with:

```bash
pkg install curl jq
```

## Installation

Quick install:

```bash
curl -fsSL https://raw.githubusercontent.com/MrStickman202/tchat/main/install.sh | bash
```

Or download the script, make it executable, and run it:

```bash
chmod +x tchat.sh
./tchat.sh
```

You can also install it globally from inside the app:

```text
/install
```

After that, you can start it from anywhere by typing:

```bash
tchat
```

## Commands

Some useful commands:

```text
/help
/search <model>
/list
/model
/default
/switch
/auth
/login
/key
/balance
/refresh
/settings
/memory
/save
/clear
/q
```

## Configuration

tchat stores its settings locally in:

```text
~/.config/tchat/
```

This folder may contain:

```text
config.json
keys.json
memory.json
```

Your API keys are stored locally on your device.

Do not upload your `keys.json` file or any real API keys to GitHub.

## Why "tchat"?

The name **tchat** stands for **Termux Chat**.

The project originally started as a lightweight AI chat client for Termux on Android. Although it has since grown to support other Bash-based terminal environments, the original name has stayed.

## Security

tchat asks for confirmation before running terminal commands.

You should still read every command before allowing it to run, especially when using an unfamiliar model.

API usage may cost money depending on the provider and model you choose.

## Status

This project is still in development, so bugs may be present and some features may change.

Bug reports and suggestions are welcome.

## Disclaimer

tchat is not affiliated with OpenAI, Google, Anthropic, or OpenRouter.
