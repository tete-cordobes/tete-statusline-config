# Tete Statusline Config

Custom Claude Code statusline with Gentleman theme colors.

## What it shows

**Line 1:** Model, output style, vim mode, session name, directory, clickable git branch, worktree, lines changed

```
🎭 Opus 4.6 Tete N  ⚡seo-sitemaps  󰉋 project   main*  🌲my-feature  +42 -12
```

**Line 2:** Context bar, cost, tokens, speed, duration, rate limits

```
ctx ███░░░░░ 42%  $3.47  ↓856.2k ↑124.5k 4833t/s  30m45s  5h 67%→2h0m 7d 24%
```

## Features

- Context window progress bar with color thresholds (green/yellow/red)
- Session cost tracking (USD)
- Token counts (input/output) with human-readable formatting (k/M)
- Token speed (tokens/second based on API duration)
- Session duration
- Rate limits (5h + 7d) with reset countdown — only shows when available
- Git branch + dirty flag (cached every 5s)
- Clickable git branch — Cmd+click opens GitHub (OSC 8 hyperlinks)
- Model icon per variant (Opus/Sonnet/Haiku)
- Output style name (shows "Tete", "default", etc.)
- Vim mode indicator (N = NORMAL, I = INSERT)
- Session name (when set with `--name`)
- Worktree indicator (when in isolated worktree)
- Gentleman theme (ANSI 256 colors)

## Widgets

All optional widgets appear only when their data is available:

| Widget | When it shows | Where |
|--------|--------------|-------|
| Output style | Always (if not "default") | Line 1, after model |
| Vim mode | When vim mode enabled | Line 1, N/I badge |
| Session name | When set with `--name` | Line 1, before dir |
| Clickable branch | When git remote exists | Line 1, Cmd+click |
| Worktree | When in `--worktree` session | Line 1, tree icon |
| Token speed | After first API response | Line 2, after tokens |
| Rate limits | Pro/Max subscribers only | Line 2, end |
| Reset countdown | When rate limit data present | Line 2, after 5h% |

## Install

```bash
# Copy the script
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

## Requirements

- `jq` (JSON parser): `brew install jq`
- `bc` (calculator): pre-installed on macOS
- Claude Code v2.1.80+ for rate limits
- Terminal with OSC 8 support for clickable links (iTerm2, Kitty, WezTerm)

## Color Thresholds

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Context | < 50% | 50-79% | >= 80% |
| Rate limits | < 50% | 50-79% | >= 80% |

## Test

```bash
# Full test (all widgets active)
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test"},"output_style":{"name":"Tete"},"vim":{"mode":"NORMAL"},"session_name":"my-session","worktree":{"name":"feature-x"},"cost":{"total_cost_usd":3.47,"total_duration_ms":1845000,"total_api_duration_ms":45000,"total_lines_added":495,"total_lines_removed":12},"context_window":{"total_input_tokens":856234,"total_output_tokens":124567,"context_window_size":1000000,"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":67.3,"resets_at":'$(($(date +%s) + 7200))'},"seven_day":{"used_percentage":23.8}}}' | ./statusline.sh

# Minimal test (no optional fields)
echo '{"model":{"display_name":"Sonnet 4.6"},"workspace":{"current_dir":"/tmp/test"},"cost":{"total_cost_usd":0.15,"total_duration_ms":300000,"total_api_duration_ms":8000,"total_lines_added":12,"total_lines_removed":3},"context_window":{"total_input_tokens":15000,"total_output_tokens":4500,"context_window_size":200000,"used_percentage":8}}' | ./statusline.sh
```

## License

MIT
