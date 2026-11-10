# Who Roost is for

## The customer

One person who runs five or more Claude Code sessions at the same time, in Terminal, on a Mac.

The typical user is a founding engineer or a solo founder. They use Claude Code for more than code: a release, a customer thread, a support ticket, an ops check. Each of these lives in its own long-running session. Many of them spawn more sessions with an orchestrator, and work on two screens.

You can see this user from far away: ten black Terminal windows, Cmd+` to cycle through them, and a session that waited an hour for one "yes".

Roost is not for:

- People with one or two sessions. Terminal tabs are enough.
- People who work in an IDE, the Claude desktop app or the web. They have a session list already.
- Teams that want a shared view of each other's agents. Roost is one person, one Mac.

## The problem

At five sessions, the bottleneck is no longer Claude. It is the person.

1. **A waiting agent does nothing.** A session that asks a question stops until you answer. With ten windows, you do not see which one asks. The cost is invisible, so nobody measures it.
2. **The right window is hard to find.** The windows look the same, the titles are cut off, and half of them are on the other screen.
3. **Everything has the same weight.** A customer thread and a test run are both one window. The window list has no priority.
4. **You forget what a session was for.** After a day, "claude" in a tab title tells you nothing.

## The promise

**Never leave an agent waiting.**

Roost puts every Claude Code session on the edge of your screen as an app icon. A red dot means it needs you. One click brings its window to the front.

## Why it works

1. **Triage at a glance.** Red dot: needs you. Orange spinner: working. Nothing: quiet. You see this without leaving the window you are in.
2. **One click, the right window.** The window comes forward and flashes, also on the other screen.
3. **Faces, not titles.** A session about a customer shows the person you talk to there, and a vendor shows its logo. People recognize a face faster than they read a title. The agents set the pictures themselves, so this costs you nothing.
4. **Your order.** Drag the icons like the Dock. Group them in topics, for example "Customers".
5. **Nothing to migrate.** Roost reads the session files that Claude Code already writes. You keep your terminal, your orchestrator and your habits. There is no wrapper, no tmux and no new way to start a session. The + tile is there if you want it.
6. **Local only.** No account, no cloud, and nothing leaves the Mac.

## Other ways to solve it

| Alternative                                    | What it lacks                                                                         |
| ---------------------------------------------- | ------------------------------------------------------------------------------------- |
| Terminal tabs and Cmd+`                        | No status and no priority.                                                            |
| tmux with a status line                        | You must move every session into tmux. The status is text.                            |
| A notification from a Claude Code hook         | It disappears. There is no overview and no order.                                     |
| Tools that run the agents for you              | You start sessions inside the tool. Roost adopts the sessions you already have.       |
| The session list in the Claude app or web      | It takes you out of the terminal.                                                     |

## Risks

- **Anthropic ships a session overview in Claude Code.** This is the biggest risk. Roost stays small and adds no lock-in, so a user loses nothing when that day comes.
- **The session files are not documented.** An update of Claude Code can break the list. The fix is in one file, `src/sessions.js`.
- **The audience is small today.** Few people run ten agents at once. That number grows with every better model.
- **Only macOS and Terminal.app.** iTerm2, Ghostty and other agent CLIs, such as Codex, are the next steps if users ask for them.

## How we know it works

The measure is the time between "needs me" and the moment the user opens the session. Roost can log both events on the Mac. It does not measure this yet.

## Model

Free and open source. The users are few and technical, and they find tools through each other. A price would stop that.
