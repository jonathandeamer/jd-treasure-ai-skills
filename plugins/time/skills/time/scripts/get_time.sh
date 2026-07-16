#!/usr/bin/env bash
#
# Prints the current time in the user's approximate local timezone,
# inferred via IP geolocation. Falls back to system local time on
# any network failure, timeout, or rate-limit.

TIMEOUT=5

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

echo "Geolocation unavailable — falling back to system local time."
date "+Current time: %A, %B %d, %Y %I:%M:%S %p %Z"
