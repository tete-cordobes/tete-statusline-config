# Tete Statusline Config

Custom Claude Code statusline with Gentleman theme colors.

## What it shows

**Line 1:** Model, directory, git branch, lines changed

```
🎭 Opus 4.6  󰉋 project   main*  +42 -12
```

**Line 2:** Context bar, cost, tokens, duration, rate limits

```
ctx ███░░░░░ 42%  $3.47  ↓856.2k ↑124.5k  30m45s  5h 67%→2h0m 7d 24%
```

## Features

- Context window progress bar with color thresholds (green/yellow/red)
- Session cost tracking (USD)
- Token counts (input/output) with human-readable formatting (k/M)
- Session duration
- Rate limits (5h + 7d) with reset countdown — only shows when available
- Git branch + dirty flag (cached every 5s)
- Model icon per variant (Opus/Sonnet/Haiku)
- Gentleman theme (ANSI 256 colors)

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

## Color Thresholds

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Context | < 50% | 50-79% | >= 80% |
| Rate limits | < 50% | 50-79% | >= 80% |

## Test

```bash
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test"},"cost":{"total_cost_usd":1.23,"total_duration_ms":600000,"total_lines_added":42,"total_lines_removed":7},"context_window":{"total_input_tokens":150000,"total_output_tokens":25000,"context_window_size":200000,"used_percentage":65},"rate_limits":{"five_hour":{"used_percentage":45.2,"resets_at":'$(($(date +%s) + 3600))'},"seven_day":{"used_percentage":12.5}}}' | ./statusline.sh
```

## License

MIT
