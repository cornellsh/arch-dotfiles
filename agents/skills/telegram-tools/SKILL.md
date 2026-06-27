---
name: telegram-tools
description: Read and send Telegram messages, list chats, and search messages from the command line. Use when the user wants to check Telegram, read a conversation, send/reply to a message, or search their Telegram history.
---

# Telegram Tools

A minimal Telegram CLI built on Telethon. One self-contained script, `tg`,
runs via `uv` (dependencies are declared inline; first run installs and caches
Telethon automatically — no venv setup needed).

## Setup

Requires `uv` (https://docs.astral.sh/uv/) and a Telegram user session.
Credentials are read from the environment:

- `TELEGRAM_API_ID`
- `TELEGRAM_API_HASH`
- `TELEGRAM_SESSION_STRING`

If those env vars are not set, the script automatically parses
`~/.zsh_secrets` for `export TELEGRAM_*=...` lines, so usually nothing extra
is needed. To generate a session string, see `~/work/telegram-mcp`
(`session_string_generator.py`).

## Usage

Run from the skill directory (or use the absolute path to `tg`):

```bash
{baseDir}/tg me                              # who am I logged in as
{baseDir}/tg chats                           # 20 most recent conversations
{baseDir}/tg chats --limit 50 --archived     # more, including archived
{baseDir}/tg read <chat>                     # last 20 messages of a chat
{baseDir}/tg read <chat> --limit 50
{baseDir}/tg search "<query>"                # global message search
{baseDir}/tg search "<query>" --chat <chat>  # search within one chat
{baseDir}/tg send <chat> "<text>"            # send a message
{baseDir}/tg reply <chat> <msg_id> "<text>"  # reply to a specific message
```

### Specifying `<chat>`

`<chat>` accepts any of:

- `@username`
- a numeric id (e.g. `-1002667278660`, as shown by `tg chats`)
- a phone number (`+15551234`)
- `me` — your own Saved Messages
- a case-insensitive **substring of a dialog title** (e.g. `operational`
  matches "UPCOMERS OPERATIONAL"). Substring matching scans your dialog list,
  so prefer an id or `@username` when you already know it.

### Output

Plain text, optimized for low token use. Messages print oldest-first as
`[msg_id] YYYY-MM-DD HH:MM Sender: text`. Add `--json` to `me`, `chats`,
`read`, or `search` for structured output you can pipe into `jq`.

## Efficiency notes

- Prefer `read --limit N` with a small N; bump it only if you need more history.
- To act on a message (reply), first `read` to get its `[msg_id]`.
- Resolving a chat by id/`@username` is instant; resolving by title substring
  iterates dialogs, so it is slower for large accounts.

## ⚠️ Sending caution

`send` and `reply` write to real conversations with other people. Before
sending to anyone other than `me` (Saved Messages), confirm the target chat
and message text with the user. When unsure which chat, run `tg chats` and
confirm the id first.
