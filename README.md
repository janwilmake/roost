# Roost

**Never leave an agent waiting.** Roost puts every Claude Code session on the edge of your screen as an app icon. A red dot means it needs you. One click brings its Terminal window to the front.

![Roost demo: hover, a click that brings a window forward, a topic, and a new session](docs/demo.gif)

Roost is for one person who runs many Claude Code sessions at once in Terminal on a Mac. It reads the session files that Claude Code already writes, so you keep your terminal and your habits. Nothing leaves the Mac. Who it is for and why: [docs/positioning.md](docs/positioning.md).

## Install

Paste this into Claude Code:

```text
Install Roost for me. Follow "Install steps" in https://github.com/janwilmake/roost/blob/main/README.md
```

Claude builds the app, adds the `roost` command, and tells every Claude session about Roost. After that you can ask any session to rename itself, change its picture or join a topic. To install by hand, follow the same [Install steps](#install-steps).

## Use

Roost is a strip of app-style tiles that stays on top in the top-left corner of each screen. It has no other window. To pin the Dock icon, right-click it and choose Options, Keep in Dock.

| Action                    | Result                                                                        |
| ------------------------- | ----------------------------------------------------------------------------- |
| Hover a tile              | It grows like the Dock. A label shows the title, status, folder and times.    |
| Click a session           | Its Terminal window comes forward and flashes an orange border.               |
| Drag a tile               | It moves to a new place in the priority order. New sessions start at the end. |
| Right-click a session     | Open, Rename, Mark as Seen, Work in Progress, Snooze or Wake, Move to Topic.  |
| Click a topic             | It expands or collapses.                                                      |
| Right-click a topic       | Expand or Collapse, Rename, Delete Topic. Deleting keeps the sessions.        |
| Click the rooster         | The overview opens: every session with its title, status and notes.          |
| Drag the rooster          | The strip moves on every screen. Right-click it to quit.                      |
| Click the + tile          | Start a session in a frequent folder or a new one, resume a recent one, or wake a snoozed one. |

Each strip fills the height of its screen: its tiles share that height, counted as at least eight tiles, so a bigger screen gets bigger tiles. When the tiles would get smaller than 22 points, the strip shows what fits, the way the Dock does. The tile under the cursor still grows.

A red dot means the session needs you, and a small orange spinner means it is working. A blue dot means nothing waits on you, but a teammate owes the next step: the `Waiting for team` count of the notes. Red always wins over blue. A gray `wip` badge means work is in progress while Claude is not thinking: it waits on a background shell, a monitor, a loop or another session. A wip session shows no red dot or count, so you don't open it for nothing. A red badge with a number counts what waits for you: the `Late` count of a customer header, or else its `Waiting for us` count, or else the items under `Waiting for you`. A topic adds up the badges of its sessions. A snoozed session leaves the strip; the Snoozed menu under + lists it, with Wake and Open. Snooze offers one-time snoozes (1 hour, 3 hours, tomorrow, 2 to 4 days, 1 or 2 weeks, 1 month, or until the weekend) and repeating ones that you switch on or off: during the week (Mon–Fri), during work hours (Mon–Fri 9–18) and during the weekend. Wake ends a one-time snooze and skips the repeating snooze that holds now. A topic shows the dot or spinner of its most urgent session. A stripe marks the end of an expanded topic.

The tooltip also shows the time spent in a session: `you 25m` counts the time its tab was in front while you used the Mac (two minutes without a key or mouse touch stops the count), and `Claude 1h 10m` counts the time Claude worked (not the time a shell command runs). The counts are kept in `~/.roost/state.json`, so a resumed session keeps them. The overview opens with two donuts that split your time and Claude's time over the sessions.

The + tile opens a new Terminal window that runs `claude --dangerously-skip-permissions` in the folder. The most used folders come from `~/.claude/history.jsonl`, counted in sessions, without the `cca` agent slots. A folder that Claude has not seen before first asks if you trust it.

A session joins a topic when you drop it directly under the topic tile, or between two of its sessions. Use Rename with an empty title to return to the automatic title. For a `cca` agent with no viewer window, Roost opens one with `screen -r`.

| Status   | Meaning                                                                  |
| -------- | ------------------------------------------------------------------------ |
| Needs me | Claude waits on a prompt, or finished a turn that you did not look at.   |
| Working  | Claude itself is busy.                                                   |
| Shell    | Claude waits on a shell command that is still running. It shows a gray `wip` badge, unless it has a count. |
| Work in progress | Claude is idle but waits on work it started: a monitor, a loop wakeup, another session. The session sets it with the roost skill, or you do with right-click, Work in Progress. Gray `wip` badge. It ends by itself when the session starts its next turn, and after 6 hours at most. |
| Quiet    | Claude is idle and you saw the result.                                   |
| Snoozed  | Off the strip until the time you chose, or during the hours of a repeating snooze. Find it under + → Snoozed. |

## For AI agents: make a topic

Pass the ids of the sessions that belong in it. A new topic starts expanded:

```bash
jq -n --arg name 'Customers' '{name: $name, sessionIds: ["<id>", "<id>"]}' |
  curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' -d @- http://127.0.0.1:4777/api/topics
```

To add one session later, send `{"topic":"<topic id>"}` to `/api/sessions/<id>`. The response of `GET /api/sessions` lists `topics` with their ids.

## For AI agents: write notes

Notes show in full when the user hovers the session, and in the overview that opens from the rooster. Use this format, and leave out a section that is empty:

```text
About: one line on what this session is for.
Waiting for you:
- each thing the user must do or decide
Waiting for others:
- each thing an outside party must do, with who
Waiting for team:
- each thing the user handed to a teammate, with who and since when
```

A session about a customer starts its notes with this header. `Waiting for us` and `Waiting for them` count the items in the two lists. `Late` counts what is late for the customer, and Roost shows it as the badge. `Waiting for team` counts what the user handed to a teammate; leave it out when it is 0. "Who" names both sides: the person on our team and the person at the customer. "When" is a date and time, for example `Tue 10 Nov 14:05`. Write `none found` when a value is not known. A session about several customers gives the header once per customer, with the customer's name in front.

```text
Late: 1 · Waiting for us: 2 · Waiting for them: 1 · Waiting for team: 1
Last meeting: Sam with Lisa (Acme), Tue 10 Nov 14:00
Last message: Lisa (Acme) → Robin, Tue 10 Nov 16:12 (email)
Next meeting: Sam with Lisa (Acme), Thu 12 Nov 10:00
```

Each of these adds one to `Late`. A thing that matches two rules counts once.

- A conversation with the customer has waited more than 24 working hours for our reply, in any channel: email, Intercom, Slack, WhatsApp or another one. Count one per conversation, not per message.
- We promised the customer something by a date, and that date passed without delivery. Count one per promise.
- Nobody had contact with the customer for more than a week, and no meeting with them is planned. This counts one at most.
- The customer reported a must-have feature or bug more than two weeks ago, and it is not fixed. Count one per item.

Put each late thing in `Waiting for you`, with the reason, for example `- (late: no reply for 2 days) answer Lisa's email about the import`.

When the user hands the next step of a late thing to a teammate, it stops counting as `Late` and moves to `Waiting for team`, with who and since when, for example `- Robin: add the Teams admin steps to the help article (asked Thu 12 Nov 14:40)`. Roost then shows a blue dot instead of the red badge, as long as nothing else is late. When the teammate replies, decide again: the next step is often ours, and then it counts as `Late` or `Waiting for us` again. When the teammate has not replied within 2 working days, it counts as `Late` again, with the reason, for example `- (late: Robin has not replied for 2 working days) …`.

Keep them under 300 words. Update them at the end of each turn in which one of the lists changed. Roost shows how old the notes are.

```bash
jq -n --arg notes "$NOTES" '{notes: $notes}' |
  curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' -d @- http://127.0.0.1:4777/api/sessions/<id>
```

The value is plain text of at most 3,000 characters. Send `null` to remove the notes.

## For AI agents: snooze a session

A snoozed session leaves the strip until it wakes. Snooze only when the user asks for it.

- `{"snoozeUntil": <ms since 1970>}` snoozes once, until that moment. `null` ends it.
- `{"snoozeRules": [...]}` sets the repeating snoozes, in the Mac's local time: `week` (Monday to Friday), `workday` (Monday to Friday, 9:00 to 18:00) and `weekend` (Saturday and Sunday). `[]` removes them. The list replaces the one before.
- `POST /api/sessions/<id>/wake` ends a one-time snooze and skips the repeating snooze that holds now.

```bash
id=$(jq -r .sessionId ~/.claude/sessions/$PPID.json)
# Until Saturday 9:00, three days from now (macOS date):
until=$(( $(date -v+3d -v9H -v0M -v0S +%s) * 1000 ))
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' \
  -d "{\"snoozeUntil\": $until}" "http://127.0.0.1:4777/api/sessions/$id"
# Snoozed during work hours, every week:
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' \
  -d '{"snoozeRules": ["workday"]}' "http://127.0.0.1:4777/api/sessions/$id"
```

## For AI agents: mark work in progress

When a turn ends while work you started still runs and will wake you (a background shell, a Monitor, a loop wakeup, a message you wait for from another session), send `wip` as the last step of the turn, with a few words on what you wait for. The tile then shows a gray `wip` badge in place of its red dot or count.

- You don't need to remove it. Roost clears it as soon as the session starts its next turn, when the work comes back or the user types. If that turn still waits, send `wip` again.
- `{"wip": null}` removes it at once. A mark ends after 6 hours at most.
- Don't send it when the turn ends with nothing running, or when the user must act: then the red dot is right.
- Don't send it from a standing watcher whose badge counts what is late: that count must stay visible.

```bash
id=$(jq -r .sessionId ~/.claude/sessions/$PPID.json)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' \
  -d '{"wip": "watching CI"}' "http://127.0.0.1:4777/api/sessions/$id"
```

## For AI agents: message another session

Claude Code's `SendMessage` tool reaches another local session by the name that `ListAgents` shows. Roost gives that name as `agentName`, next to the title, topic and notes. So one request finds the sessions to message, for example every session in a topic:

```bash
curl -s http://127.0.0.1:4777/api/sessions |
  jq -r --arg topic 'Customers' '(.topics[] | select(.name == $topic) | .id) as $id | .sessions[] | select(.topic == $id) | [.agentName, .title] | @tsv'
```

## For AI agents: set a session's picture

The app has no picture controls. An agent sets each picture through the local API while Roost runs. A Claude Code hook, `bin/picture-hook.sh`, asks each session that has no picture to set one.

Pick the picture in this order:

1. The thread is with one person: use a photo of that person.
2. The thread is with an organization, not one person: use its logo.
3. Neither: be creative. Use one emoji that fits the subject, or a fitting picture from elsewhere.

Use any tool you have to find it: your own CRM or database (read-only), a LinkedIn or Slack profile, or the `apple-touch-icon.png` of the organization's website. Put a pointer to your own sources in `~/.roost/rules.md`. The picture stays on this Mac, in `~/.roost/state.json`.

A session finds its own id with `jq -r .sessionId ~/.claude/sessions/$PPID.json`. To find another session, list them all:

```bash
curl -s http://127.0.0.1:4777/api/sessions | jq -r '.sessions[] | [.id, .title] | @tsv'
```

Set an emoji. A photo takes priority over an emoji, so clear the photo if the session has one:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' \
  -d '{"emoji":"🧪","photo":null}' http://127.0.0.1:4777/api/sessions/<id>
```

Set a photo. Crop it to a square first if it is not square. The strip shows it at up to 80 points, so 256 pixels stays sharp on a Retina screen:

```bash
sips -s format jpeg -z 256 256 face.png --out face.jpg
jq -n --arg photo "data:image/jpeg;base64,$(base64 -i face.jpg)" '{photo: $photo}' |
  curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' -d @- \
  http://127.0.0.1:4777/api/sessions/<id>
```

The value must be a base64 `data:image/jpeg`, `png` or `webp` URL of at most 400,000 characters. The API answers 200 on success and 400 on a bad value. The same request also accepts `title`. A session without a picture shows a default animal.

## Install steps

Do these steps in order. Tell the user what you did at the end. In the commands, `$ROOST` is the folder of the clone.

1. **Check the requirements.** You need macOS 13 or later, Node 20 or later (`node -v`), `jq` (`jq --version`), and Swift (`swiftc --version`). If Swift is missing, ask the user to run `xcode-select --install`, and stop until it is installed.
2. **Clone.** Clone `https://github.com/janwilmake/roost` into `~/roost`, unless the user names another folder. If the clone already exists, run `git pull` in it.
3. **Build.** In `$ROOST`, run `./scripts/build-app.sh`. It builds `~/Applications/Roost.app`. Run it again after a change of the Node version or a move of the folder.
4. **Add the command.** Run `mkdir -p ~/.local/bin && ln -sf "$ROOST/bin/roost.js" ~/.local/bin/roost`. If `~/.local/bin` is not on the `PATH`, tell the user.
5. **Add the picture hook.** It asks each session without a picture to set one. This command keeps every other setting and adds the hook only once:

   ```bash
   f=~/.claude/settings.json; [ -f "$f" ] || echo '{}' > "$f"
   jq --arg cmd "$ROOST/bin/picture-hook.sh" \
     'if any(.hooks.UserPromptSubmit[]?.hooks[]?; .command == $cmd) then . else .hooks.UserPromptSubmit += [{hooks: [{type: "command", command: $cmd, timeout: 5}]}] end' \
     "$f" > "$f.tmp" && mv "$f.tmp" "$f"
   ```

6. **Add the skill.** Run `mkdir -p ~/.claude/skills && ln -sfn "$ROOST/skills/roost" ~/.claude/skills/roost`. Every session sees the `roost` skill, which tells it to keep its notes, badge and picture current after each turn.

   Your own rules, for example where to find a contact's photo, go in `~/.roost/rules.md`. A repository can add its own rules in a section headed `Roost` in its `CLAUDE.md` or `AGENTS.md`. They replace your rules on the points they cover.

7. **Open Roost.** Run `open ~/Applications/Roost.app`. Tell the user that macOS asks once for permission to control Terminal, and that Roost needs it. The hook and the skill work in sessions that start after the install.

## How it works

- `src/server.js` listens on `127.0.0.1:4777` only. It refuses other hosts and origins.
- It reads `~/.claude/sessions/<pid>.json`, `ps`, and the Terminal tab list through AppleScript. It never opens the `.key` files in that folder.
- Pictures, titles, order, snooze times and repeating snoozes are in `~/.roost/state.json`, keyed by session id. A resumed session keeps them.
- `app/main.swift` is the native app. It starts the server if needed, draws the strip and the logo, and reads the sessions from the server.

The session files are an undocumented part of Claude Code. If the list goes empty after an update, look there first.

Settings for tests: `ROOST_PORT`, `ROOST_HOME`, `ROOST_SESSIONS_DIR`. Run the tests with `npm test`.
