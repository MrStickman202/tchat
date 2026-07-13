<img width="768" height="512" alt="Jul 14, 2026, 01_13_17 AM" src="https://github.com/user-attachments/assets/103d7d4a-cb6f-4d17-bf0a-b6d805ca7156" />

# tchat

tchat is a lightweight terminal app that lets you chat with AI models using your own API keys.

I created it to be fast, simple, and usable from a terminal without needing a full desktop app. It can be used for everyday conversations, coding, debugging, working with files, and running approved terminal commands.

It was primarily built for Termux on Android, but it is designed to work in other Bash-based terminal environments as well.

Every feature, idea, design decision, improvement, and bug fix was planned and directed by me. AI was used as a coding assistant during development, while I handled the overall architecture, testing, debugging, and refinement of the project.

## Features

* Supports multiple AI providers
* Lets you use your own API keys
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

Download the script, make it executable, and run it:

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
