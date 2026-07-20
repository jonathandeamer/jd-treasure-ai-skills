---
name: time
description: Use when the user runs /time or asks "what time is it", "what's the current time", "what time is it for me", or similar. Asks the user for their city or timezone, then runs a bundled bash script to report the current local time — never attempts IP geolocation.
---

Report the user's current local time. Always ask for their location first — do not attempt IP geolocation and do not guess.

## Steps

1. **Ask the user what city or timezone they're in** (e.g. via `AskUserQuestion` if available, otherwise a direct question: "What city or timezone are you in?"). Do this every time the skill runs — do not reuse a location from earlier in the conversation unless the user just told you it, and do not attempt any geolocation lookup.

2. Once they answer with a city, region, or timezone name, resolve it to an IANA timezone (e.g. "Tokyo" → `Asia/Tokyo`, "New York" → `America/New_York`, "London" → `Europe/London`) using your own knowledge.

3. Run the bundled script with Bash, resolved **relative to this skill's own base directory** (shown at the top of this skill's invocation as "Base directory for this skill: <path>") — never hardcode `$HOME/.treasure-work/...`, since that path only exists on the desktop app and not in other runtimes (e.g. Treasure AI Studio's sandboxed environment):
   ```bash
   bash "<base directory for this skill>/scripts/get_time.sh" "Asia/Tokyo"
   ```
   For example, if the base directory shown is `/home/agent/.treasure-work/.claude/skills/time`, run `bash "/home/agent/.treasure-work/.claude/skills/time/scripts/get_time.sh" "Asia/Tokyo"`.

4. Relay the script's output to the user as-is.

5. **If the user declines to share their location, or you can't confidently resolve what they said to an IANA timezone** — run the script with `--fallback` and clearly label the result as the machine's system time, not a user-confirmed one:
   ```bash
   bash "<base directory for this skill>/scripts/get_time.sh" --fallback
   ```

## Notes

- This skill never makes a network call or IP geolocation lookup — it only formats time for a timezone you already know, using Python's `zoneinfo`.
- If the script prints `INVALID_TIMEZONE`, the resolved zone string wasn't a valid IANA name — ask the user to clarify their city/region and try again, or fall back to `--fallback`.

## Examples

### Example 1: User gives a city
**Input:** `/time`
**Claude asks:** "What city or timezone are you in?"
**User:** "Tokyo"
**Claude runs:** `bash ".../scripts/get_time.sh" "Asia/Tokyo"`
**Output:**
```
Timezone: Asia/Tokyo
Current time: Thursday, July 16, 2026 08:39:00 PM JST (UTC+0900)
```

### Example 2: User declines to share location
**Input:** `/time`
**Claude asks:** "What city or timezone are you in?"
**User:** "I'd rather not say"
**Claude runs:** `bash ".../scripts/get_time.sh" --fallback`
**Output:**
```
No timezone provided — using system local time.
Current time: Thursday, July 16, 2026 01:39:00 PM CEST
```
