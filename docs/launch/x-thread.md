# X thread

Attach `site/public/demo.gif` to post 1.

---

**1/**

I run ~10 Claude Code sessions at once. The slow part stopped being Claude. It's me, finding the one window that has been asking "proceed?" for an hour.

So I built Roost: a strip of tiles at the edge of my Mac screen, one per session.

https://roostmac.com

---

**2/**

Red dot: the session needs you.
Orange spinner: it's working.
No mark: it's quiet.

One click brings its Terminal window to the front and flashes its border, also on the other screen.

---

**3/**

It doesn't wrap Claude Code. It reads the session files Claude Code already writes, so you keep starting `claude` in Terminal like you do now. No tmux, no new launcher.

---

**4/**

Each session sets its own picture, color and notes through a local API. A customer thread shows the customer's face, a vendor its logo. Hover to read what it waits on.

Plus topics, snooze, a "This week" folder for deadlines, and Restart All with `claude --resume`.

---

**5/**

Local only. No account, no telemetry, license checked offline.

Limits: Terminal.app only (no iTerm2/Ghostty yet), macOS 13+, Apple Silicon. It reads undocumented files, so a Claude Code update can break it until I ship a fix.

---

**6/**

The code is MIT on GitHub: https://github.com/janwilmake/roost

The app: 14-day trial with everything, then free for up to 3 sessions. $49 once for unlimited sessions and all 1.x updates. You pay for the ready-made app; you can also build it yourself.

---

**7/**

If you run 5+ agents in parallel, I'd like to know how you keep track of them today, and which terminal you'd want next.

https://roostmac.com
