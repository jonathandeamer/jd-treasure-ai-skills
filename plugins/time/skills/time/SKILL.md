---
name: time
description: Use when the user runs /time or asks "what time is it", "what's the current time", "what time is it for me", or similar. Determines the user's current local time based on their approximate location (IP geolocation) by running a bundled bash script, asking the user for their location/timezone if geolocation is unavailable.
---

Report the user's current local time by running the bundled script — do not compute the time yourself.

## Steps

1. Run the bundled script with Bash, resolved **relative to this skill's own base directory** (shown at the top of this skill's invocation as "Base directory for this skill: <path>") — never hardcode `$HOME/.treasure-work/...`, since that path only exists on the desktop app and not in other runtimes (e.g. Treasure AI Studio's sandboxed environment):
   ```bash
   bash "<base directory for this skill>/scripts/get_time.sh"
   ```
   For example, if the base directory shown is `/home/agent/.treasure-work/.claude/skills/time`, run `bash "/home/agent/.treasure-work/.claude/skills/time/scripts/get_time.sh"`.

2. **If the script prints a location, timezone, and current time** — geolocation succeeded. Relay the output to the user as-is.

3. **If the script prints `GEOLOCATION_FAILED` (exit code 2)** — do not fall back to system time silently. Instead, ask the user what city they're in or what timezone they're in (e.g. via `AskUserQuestion` if available, otherwise a direct question).
   - Once they answer with a city or region, resolve it to an IANA timezone (e.g. "Tokyo" → `Asia/Tokyo`, "New York" → `America/New_York`) using your own knowledge.
   - Re-run the script with that timezone as an argument to get an accurate, offline-formatted time:
     ```bash
     bash "<base directory for this skill>/scripts/get_time.sh" "Asia/Tokyo"
     ```
   - Relay that output to the user.
   - If the user declines to share their location, or you can't confidently resolve what they said to an IANA timezone, run the script with `--fallback` and clearly label the result as the machine's system time, not a geolocation- or user-confirmed one:
     ```bash
     bash "<base directory for this skill>/scripts/get_time.sh" --fallback
     ```

## Notes

- The script calls a public IP-geolocation API (`ipapi.co`) to infer city/region/country and IANA timezone, then prints the current time in that timezone using Python's `zoneinfo`. No arguments, API keys, or user input are required for this path.
- Passing an IANA timezone string as the first argument skips the network call and formats the time for that zone directly — use this after the user tells you their location.
- `--fallback` prints system local time, explicitly labeled as such. Only use this if the user declines to share their location or you can't resolve what they said.

## Examples

### Example 1: Geolocation succeeds
**Input:** `/time`
**Output:**
```
Location: San Francisco, California, US
Timezone: America/Los_Angeles
Current time: Thursday, July 16, 2026 09:14:22 AM PDT (UTC-0700)
```

### Example 2: Geolocation fails — ask the user
**Input:** `/time` (script returns `GEOLOCATION_FAILED`)
**Claude asks:** "I couldn't determine your location automatically — what city or timezone are you in?"
**User:** "Tokyo"
**Claude runs:** `bash ".../scripts/get_time.sh" "Asia/Tokyo"`
**Output:**
```
Timezone: Asia/Tokyo
Current time: Thursday, July 16, 2026 08:39:00 PM JST (UTC+0900)
```
