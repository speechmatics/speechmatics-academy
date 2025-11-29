#!/usr/bin/env python3
"""
CLI tool to initiate outbound calls.

Usage:
    python dial.py +14155551234 --server https://abc123.ngrok-free.dev
"""

import argparse
import os
import sys

import requests
from dotenv import load_dotenv
from twilio.rest import Client

load_dotenv()


def dial_via_server(to_number: str, server_url: str):
    """Call the server's /dial endpoint to initiate the call."""
    dial_url = f"{server_url.rstrip('/')}/dial"

    print(f"Calling {to_number}...")
    print(f"Server: {dial_url}")

    try:
        response = requests.post(dial_url, json={"to": to_number}, timeout=30)
        data = response.json()

        if response.ok and data.get("success"):
            print(f"\nCall initiated! (SID: {data['call_sid']})")
            print("Answer your phone to talk to the assistant!")
        else:
            print(f"Error: {data.get('error', 'Unknown error')}")
            sys.exit(1)

    except requests.exceptions.ConnectionError:
        print(f"Error: Could not connect to {server_url}")
        print("Make sure the server is running (python main.py)")
        sys.exit(1)


def dial_direct(to_number: str, webhook_url: str):
    """Call Twilio API directly (standalone mode)."""
    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    from_number = os.getenv("TWILIO_PHONE_NUMBER")

    if not all([account_sid, auth_token, from_number]):
        print("Error: Missing TWILIO_* credentials in .env")
        sys.exit(1)

    print(f"Calling {to_number} via Twilio API...")
    print(f"Webhook: {webhook_url}")

    client = Client(account_sid, auth_token)
    call = client.calls.create(to=to_number, from_=from_number, url=webhook_url)

    print(f"\nCall initiated! (SID: {call.sid})")
    print("Answer your phone to talk to the assistant!")


def main():
    parser = argparse.ArgumentParser(description="Make the AI assistant call a phone number")
    parser.add_argument("to_number", help="Phone number to call (E.164 format: +14155551234)")

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--server", metavar="URL", help="Server URL (e.g., https://abc123.ngrok-free.dev)")
    group.add_argument("--webhook", metavar="URL", help="Direct webhook URL (e.g., https://abc123.ngrok-free.dev/twiml)")

    args = parser.parse_args()

    if not args.to_number.startswith("+"):
        print("Warning: Phone number should start with + (E.164 format)\n")

    if args.server:
        dial_via_server(args.to_number, args.server)
    else:
        dial_direct(args.to_number, args.webhook)


if __name__ == "__main__":
    main()
