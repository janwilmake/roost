---
name: roost
description: Keeps this session's tile in Roost (the strip of session tiles at the left edge of the screen) current — its notes, the badge that Roost counts from those notes, its picture and its title. Use it in every Claude Code session, as a side step at the end of any turn in which something started or stopped waiting on the user or on someone else, or the subject or the person of the session changed; when a Roost note says the session has no picture or notes; and when someone asks how Roost works or asks to change this session's title, picture, notes, topic or place in the strip.
---

# Roost

Roost shows every running Claude Code session as a tile with a picture, a title, a status and a badge. The user reads the badge to decide which session needs them next. A wrong badge sends them to the wrong session, so keep it true.

Roost runs on `http://127.0.0.1:4777`. When it does not answer, skip every step below and say nothing.

## Which rules apply

1. The user's own rules: `~/.roost/rules.md`, if it exists.
2. The project's rules: a section headed `Roost` in the `CLAUDE.md` or `AGENTS.md` of the repository you work in, if it has one.
3. A project rule replaces the user's rule on the same point. A user rule on a point the project does not cover still applies.

The rules say, for example, where to find the photo of a contact, or which header a customer session uses.

This session's id: `jq -r .sessionId ~/.claude/sessions/$PPID.json`.

## After every turn

At the end of each turn, ask: did an item that waits for the user, or for someone else, appear or disappear? Did the subject of the session change?

- **Yes: update the notes.** Roost counts the badge from the notes, so the notes are the badge. Write them again in full.
- **No: do nothing.** Do not send the same notes again.

Do it as a side step. Do not mention it to the user unless it fails.

### The notes

```text
About: one line on what this session is for.
Waiting for you:
- each thing the user must do or decide
Waiting for others:
- each thing an outside party must do, with who
```

Leave out a section that is empty. Keep the notes under 300 words.

The badge is the number of items under `Waiting for you`. A customer session starts with a header line instead, and Roost counts its badge from that header (`Late`, else `Waiting for us`). The header format and the rules for `Late` are in the Roost README (`../../README.md` from the folder of this skill), section "For AI agents: write notes".

Put an item under `Waiting for you` only when the user must act. An item that waits for a release, a date or another person goes under `Waiting for others`. When the work is done, `Waiting for you` is empty and the badge is 0.

### Send the notes

```bash
id=$(jq -r .sessionId ~/.claude/sessions/$PPID.json)
jq -n --arg notes "$NOTES" '{notes: $notes}' |
  curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' -d @- \
  "http://127.0.0.1:4777/api/sessions/$id"
```

The API answers 200. `null` removes the notes.

## The picture and the title

Set or change the picture when it makes sense:

- the session has no picture yet, and its subject is clear; or
- the subject moved to another person or organization, and the picture now shows the wrong one.

Do not change a picture the user chose, unless they ask.

Pick the picture in this order:

1. The session is about one person: a photo of that person.
2. It is about an organization: its logo.
3. Neither: one emoji that fits the subject.

Find it with the tools you have, and with the sources the rules above name. The commands to send a photo, an emoji or a title are in the Roost README (`../../README.md` from the folder of this skill), section "For AI agents: set a session's picture". Crop a photo to a square of 256 pixels first.

Set a title of a few words when the automatic one does not say what the session is for. Send `{"title": "..."}` to the same endpoint.
