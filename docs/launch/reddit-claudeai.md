# r/ClaudeAI

Flair: "Built with Claude" (or the subreddit's project flair). Attach `site/public/demo.gif`.

## Title

I made a Mac app that shows which of my Claude Code sessions is waiting for me

## Body

Once I had more than five Claude Code sessions open in Terminal, I kept losing time to one thing: a session that had asked a question and was waiting for a "yes", hidden behind nine other black windows. Cmd+` through all of them gets old fast.

Roost is a strip of app-style tiles at the left edge of the screen, one per session:

- **Red dot**: the session needs you. **Orange spinner**: it's working. No mark: quiet.
- **Click** a tile and its Terminal window comes to the front, with a flash so you see which one, also on a second screen.
- **Hover** and you see the title, folder, status and the session's own notes.
- Sessions **set their own picture, color and notes** through a local API, so a support thread can show the customer's face and a release can show 🚀. The Terminal tab gets the same color as the tile.
- **Topics** to group tiles, **snooze** (once or every work day), a **This week** folder for sessions whose notes have a deadline, **Wide Mode** (3 per row) and **Restart All** (`claude --resume` for every session).

It doesn't wrap Claude Code. It reads the session files Claude Code already writes under `~/.claude`, so you start sessions the way you already do. It runs fully local: no account, no telemetry, the license is checked offline.

What it doesn't do (yet):

- Only Terminal.app. No iTerm2, Ghostty or VS Code terminal.
- macOS 13+ and Apple Silicon only.
- Those session files aren't a documented format, so a Claude Code update can break it until I push a fix.
- Not notarized yet, so the first launch needs System Settings → Privacy & Security → Open Anyway.

Price: the source is MIT on GitHub (https://github.com/janwilmake/roost), so you can build it yourself. The ready-made app has a 14-day trial with everything, then stays free for up to 3 sessions. A $49 one-time license gives unlimited sessions and all 1.x updates, with a 14-day refund.

https://ROOST_SITE

If you run a lot of parallel sessions, how do you keep track of them now? And which terminal should be next?
