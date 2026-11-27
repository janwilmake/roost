# Product Hunt

## Name

Roost

## Tagline (60 characters max)

See which Claude Code session needs you, at a glance

## Topics

Mac, Developer Tools, Artificial Intelligence

## Description (260 characters max)

A strip of tiles at the edge of your Mac screen, one per Claude Code session in Terminal. A red dot means it needs you; a click brings its window forward. Local only. 14-day trial, then free for 3 sessions or $49 once. Source is MIT.

## Gallery

1. `site/public/demo.gif`
2. The strip with a red dot, a spinner and a hover label open
3. A topic expanded, next to a session's notes
4. Wide Mode on a large screen

## Links

- Website: https://ROOST_SITE
- GitHub: https://github.com/janwilmake/roost

## First comment

Hi, I'm Jan, and I made Roost.

I run a lot of Claude Code sessions side by side in Terminal: a release, support threads, a flaky test, a refactor. Past five or so, the bottleneck wasn't Claude anymore. It was me, cycling through identical windows to find the one that had asked a question an hour ago.

Roost puts one tile per session at the left edge of the screen:

- A red dot means the session needs you, and an orange spinner means it's working.
- A click brings its Terminal window forward, also on your other screen.
- Sessions set their own picture, color and notes, so you recognize them without reading titles.
- Topics, snooze, a "This week" folder for deadlines, Wide Mode, and Restart All.

It reads the files Claude Code already writes, so there's no wrapper and nothing to change in how you work. It's local only: no account, no telemetry, offline license check.

To be upfront about the limits: it works with Terminal.app only for now (not iTerm2 or Ghostty), needs macOS 13+ on Apple Silicon, and depends on undocumented Claude Code files, so an update on their side can break it until I ship a fix.

The code is open source (MIT) on GitHub. The ready-made app is free for 14 days with everything, then free for up to 3 sessions. A $49 one-time license unlocks unlimited sessions and every 1.x update, and has a 14-day refund.

I'd like to hear which terminal you'd want supported next.
