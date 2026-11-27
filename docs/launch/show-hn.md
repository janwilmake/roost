# Show HN

## Title

Show HN: Roost – A Dock-like strip for your Claude Code sessions in Terminal (macOS)

## First comment

Hi HN, I'm Jan. I run between five and fifteen Claude Code sessions at once: a release, a couple of support threads, a flaky test, an ops check. Each lives in its own Terminal window. At some point I noticed that Claude was no longer the slow part. I was. A session would ask "tag v2.4.0 and push?" and then sit there for an hour, because it was the seventh window in the Cmd+` cycle and on the other screen.

Roost is a small native Mac app that puts a column of app-style tiles at the left edge of the screen, one per Claude Code session. A red dot means the session needs you. An orange spinner means it's working. A click brings its Terminal window forward and flashes its border, also on the other screen.

How it works:

- It reads the session files Claude Code already writes on your Mac. There's no wrapper, no tmux and no new way to start a session. You keep starting `claude` the way you do now.
- A local API on 127.0.0.1 lets each session set its own picture, color and notes. A customer thread can show the person's face, a vendor its logo. The notes show when you hover the tile.
- Topics group tiles. You can snooze a session (once, or every work day), and a "This week" folder collects the sessions whose notes have a deadline before Monday.
- Wide Mode shows a grid of three per row. Restart All quits Terminal and reopens every session with `claude --resume`, keeping their place and pictures.
- Nothing leaves the Mac. No account, no telemetry, and the license is checked offline.

Limits, so you don't have to find out yourself:

- Terminal.app only for now. iTerm2 and Ghostty are not supported yet.
- macOS 13+ on Apple Silicon.
- The session files aren't documented by Anthropic, so a Claude Code update can break the list until I ship a fix.
- The app isn't notarized yet, so the first open needs System Settings → Privacy & Security → Open Anyway.

Pricing: the source is MIT on GitHub (https://github.com/janwilmake/roost), and you can build it yourself. The ready-made app is a 14-day trial with everything, then free for up to 3 sessions. A $49 one-time license unlocks unlimited sessions and includes every 1.x update. That money is what pays for my time on it.

The obvious question is whether Anthropic will ship this inside Claude Code. They might. Roost adds no lock-in, so if they do, you uninstall it and nothing about your sessions changes.

I'd like to hear from people who run many agents at once: how do you find the one that's waiting? And if you use iTerm2 or Ghostty, tell me, because that decides what comes next.

Site: https://ROOST_SITE
