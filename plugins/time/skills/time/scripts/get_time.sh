#!/usr/bin/env bash
#
# Modes:
#   get_time.sh                    Try IP geolocation. On success, prints
#                                   location + timezone + current time.
#                                   On failure, prints "GEOLOCATION_FAILED"
#                                   and exits 2 — the caller (the skill)
#                                   should then ask the user for their
#                                   location/timezone rather than silently
#                                   falling back.
#
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

TIMEOUT=5

print_system_fallback() {
  echo "Geolocation unavailable and no timezone provided — using system local time."
  date "+Current time: %A, %B %d, %Y %I:%M:%S %p %Z"
}

if [ "$1" = "--fallback" ]; then
  print_system_fallback
  exit 0
fi

if [ -n "$1" ]; then
  # A timezone was supplied directly — format offline, no network call.
  if python3 - "$1" <<'PYEOF'
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
  then
    exit 0
  else
    exit 1
  fi
fi

# No argument — attempt IP geolocation.
geo_json=$(curl -fsS --max-time "$TIMEOUT" "https://ipapi.co/json/" 2>/dev/null)
curl_status=$?

if [ "$curl_status" -eq 0 ] && [ -n "$geo_json" ]; then
  if python3 - "$geo_json" <<'PYEOF'
import sys, json, datetime
try:
    data = json.loads(sys.argv[1])
    tz = data.get("timezone")
    if not tz:
        raise ValueError("no timezone in geolocation response")
    from zoneinfo import ZoneInfo
    now = datetime.datetime.now(ZoneInfo(tz))
    loc = ", ".join(p for p in [data.get("city"), data.get("region"), data.get("country_name")] if p)
    print(f"Location: {loc or 'unknown'}")
    print(f"Timezone: {tz}")
    print(f"Current time: {now.strftime('%A, %B %d, %Y %I:%M:%S %p %Z (UTC%z)')}")
except Exception:
    sys.exit(1)
PYEOF
  then
    exit 0
  fi
fi

echo "GEOLOCATION_FAILED"
exit 2
