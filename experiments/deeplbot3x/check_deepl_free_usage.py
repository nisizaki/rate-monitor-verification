"""Manual private-terminal check only. This file has not called the API."""
import getpass
import json
import sys
import urllib.error
import urllib.request
import warnings
from datetime import datetime, timezone

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def main():
    if not sys.stdin.isatty():
        raise SystemExit("Use a private interactive terminal; input must not be piped.")
    warnings.simplefilter("error", getpass.GetPassWarning)
    key = None
    try:
        key = getpass.getpass("DeepL API Free key (hidden; not saved): ")
        if not key or "\r" in key or "\n" in key:
            raise SystemExit("Invalid input; no request sent.")
        req = urllib.request.Request(
            "https://api-free.deepl.com/v2/usage",
            headers={"Authorization": "DeepL-Auth-Key " + key},
            method="GET",
        )
        # No proxy inherited from environment; no redirects; default TLS validation.
        opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), NoRedirect()
        )
        with opener.open(req, timeout=15) as response:
            body = response.read(1048577)
        if len(body) > 1048576:
            raise ValueError("oversized")
        data = json.loads(body)
        used, limit = data.get("character_count"), data.get("character_limit")
        if type(used) is not int or type(limit) is not int or used < 0 or limit < 0:
            raise ValueError("unexpected")
        print(json.dumps({
            "checked_at_utc": datetime.now(timezone.utc).isoformat(),
            "character_count": used, "character_limit": limit,
            "remaining_characters": max(0, limit-used),
            "scope": "account_current_billing_period",
            "source": "DeepL_API_Free_usage",
            "freshness": "near_real_time_may_lag_minutes",
        }, indent=2))
    except urllib.error.HTTPError as error:
        print("Usage request failed; HTTP status:", error.code, file=sys.stderr)
        return 1
    except (Exception, KeyboardInterrupt):
        print("Usage check stopped; details suppressed to protect secrets.", file=sys.stderr)
        return 1
    finally:
        key = None  # No durable storage; Python memory erasure is not guaranteed.
    return 0

if __name__ == "__main__":
    sys.exit(main())
