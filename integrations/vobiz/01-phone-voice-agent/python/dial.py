#!/usr/bin/env python3
"""
Place an outbound call that is answered by the voice agent in main.py.

Usage:
    python dial.py +919876543210 --answer-url https://<tunnel>/answer/<token>

The call is placed from VOBIZ_FROM_NUMBER through the Vobiz Make Call API.
When the callee picks up, Vobiz fetches the answer URL and connects the call
to the agent.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

from dotenv import load_dotenv

load_dotenv()

VOBIZ_API_BASE = "https://api.vobiz.ai/api/v1"


def place_call(to: str, answer_url: str) -> dict:
    auth_id = os.getenv("VOBIZ_AUTH_ID")
    auth_token = os.getenv("VOBIZ_AUTH_TOKEN")
    from_number = os.getenv("VOBIZ_FROM_NUMBER")
    missing = [
        name
        for name, value in (
            ("VOBIZ_AUTH_ID", auth_id),
            ("VOBIZ_AUTH_TOKEN", auth_token),
            ("VOBIZ_FROM_NUMBER", from_number),
        )
        if not value
    ]
    if missing:
        sys.exit(f"Missing required settings in .env: {', '.join(missing)}")

    body = {
        "from": from_number,
        "to": to,
        "answer_url": answer_url,
        "answer_method": "POST",
        "hangup_url": answer_url.replace("/answer/", "/hangup/"),
        "hangup_method": "POST",
        "time_limit": 600,  # seconds; a safety cap for a demo call
    }
    request = urllib.request.Request(
        f"{VOBIZ_API_BASE}/Account/{auth_id}/Call/",
        method="POST",
        data=json.dumps(body).encode(),
        headers={
            "X-Auth-ID": auth_id,
            "X-Auth-Token": auth_token,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"Vobiz returned {e.code}: {e.read().decode(errors='replace')[:300]}")
    except urllib.error.URLError as e:
        sys.exit(f"Could not reach the Vobiz API: {e.reason}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Call a phone number with the Speechmatics voice agent.")
    parser.add_argument("to", help="destination number in E.164 format, for example +919876543210")
    parser.add_argument("--answer-url", required=True, help="the Answer URL printed by main.py")
    args = parser.parse_args()

    if not args.to.startswith("+"):
        sys.exit("Use E.164 format with the country code, for example +919876543210")
    if not args.answer_url.startswith("https://"):
        sys.exit("--answer-url must be the https:// Answer URL printed by main.py")

    result = place_call(args.to, args.answer_url)
    print(f"Calling {args.to} (request_uuid={result.get('request_uuid')})")


if __name__ == "__main__":
    main()
