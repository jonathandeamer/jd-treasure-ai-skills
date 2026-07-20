#!/usr/bin/env bash
#
# Modes:
#   get_time.sh <iana_timezone>    Prints the current time in the given
#                                   IANA timezone (e.g. "America/Los_Angeles"),
#                                   offline — no network call. Use this after
#                                   the user has told you their city/timezone
#                                   and you've resolved it to an IANA zone.
#
#   get_time.sh --fallback         Prints current system local time,
#                                   explicitly labeled as such. Only use
#                                   this if the user declines to share their
#                                   location/timezone.
#
# This script never performs IP geolocation or any network call — it only
# formats time for a timezone the caller already knows.

print_system_fallback() {
  echo "No timezone provided — using system local time."
  date "+Current time: %A, %B %d, %Y %I:%M:%S %p %Z"
}

if [ "$1" = "--fallback" ]; then
  print_system_fallback
  exit 0
fi

if [ -z "$1" ]; then
  echo "USAGE: get_time.sh <iana_timezone> | --fallback" >&2
  exit 1
fi

python3 - "$1" <<'PYEOF'
import sys, datetime
try:
    from zoneinfo import ZoneInfo
    tz = sys.argv[1]
    now = datetime.datetime.now(ZoneInfo(tz))
    print(f"Timezone: {tz}")
    print(f"Current time: {now.strftime('%A, %B %d, %Y %I:%M:%S %p %Z (UTC%z)')}")
except Exception as e:
    print(f"INVALID_TIMEZONE: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
