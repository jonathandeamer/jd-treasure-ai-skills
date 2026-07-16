---
name: time
description: Use when the user runs /time or asks "what time is it", "what's the current time", "what time is it for me", or similar. Determines the user's current local time based on their approximate location (IP geolocation) by running a bundled bash script, falling back to the system's local timezone if geolocation is unavailable.
---

Report the user's current local time by running the bundled script — do not compute the time yourself.

## Steps

1. Run the bundled script with Bash, resolved **relative to this skill's own base directory** (shown at the top of this skill's invocation as "Base directory for this skill: <path>") — never hardcode `$HOME/.treasure-work/...`, since that path only exists on the desktop app and not in other runtimes (e.g. Treasure AI Studio's sandboxed environment):
   ```bash
   bash "<base directory for this skill>/scripts/get_time.sh"
   ```
   For example, if the base directory shown is `/home/agent/.treasure-work/.claude/skills/time`, run `bash "/home/agent/.treasure-work/.claude/skills/time/scripts/get_time.sh"`.
2. Relay its output to the user as-is (location, timezone, and formatted current time).
3. If the script reports it fell back to system local time (geolocation failed or timed out), mention that the time shown is the machine's local timezone rather than a geolocation-confirmed one.

## Notes

- The script calls a public IP-geolocation API (`ipapi.co`) to infer city/region/country and IANA timezone, then prints the current time in that timezone using Python's `zoneinfo`.
- No arguments, API keys, or user input are required.
- If the network call fails, times out, or is rate-limited, the script automatically falls back to the system's local time via `date` — it never errors out silently.

## Example

**Input:** `/time`
**Output:**
```
Location: San Francisco, California, US
Timezone: America/Los_Angeles
Current time: Thursday, July 16, 2026 09:14:22 AM PDT (UTC-0700)
```
