#!/bin/bash
# Claude Code UserPromptSubmit hook. When Roost runs and this session has no picture yet,
# it adds a note that asks Claude to set one. It prints nothing in every other case.
id=$(jq -r '.session_id // empty')
[ -n "$id" ] || exit 0
set=$(curl -s --max-time 1 http://127.0.0.1:4777/api/sessions | jq -r --arg id "$id" '.sessions[]? | select(.id == $id) | .pictureSet')
[ "$set" = "false" ] || exit 0
readme="$(cd "$(dirname "$0")/.." && pwd)/README.md"
cat <<EOF
Roost (the session strip on this Mac) has no picture for this session yet. Session id: $id.
When the subject of this session is clear, set a picture as a side step. Follow "For AI agents: set a session's picture" in $readme.
If the subject is not clear yet, skip it: this note comes back with the next message. Do not mention the picture to the user unless it fails.
EOF
