# Python tests

Pytest suite covering the pieces of `../proxy.py` that map to the
integration requirements — audio queueing, call-session routing, answer
XML generation, Vobiz number setup, and Vobiz audio stream event handling.
It uses a fake WebSocket and mocks the Speechmatics client and the Vobiz
API, so no live services (Vobiz, Speechmatics, ngrok) are contacted while
the tests run.

## Run

From the `python/` folder:

```bash
pip install -r requirements-dev.txt
pytest
```

## Layout

```
tests/
├── conftest.py              # fake WebSocket + canned Vobiz event fixtures
├── test_answer_xml.py       # <Response> / <Stream> / <Speak> / <Dial> shape
├── test_audio_queue.py      # AsyncQueueSource blocking/EOF semantics
├── test_call_session.py     # frame routing, wire-format constants
├── test_handler.py          # handle_vobiz_call end-to-end (mocked)
├── test_key_check.py        # Speechmatics key checked before any changes
├── test_outbound_call.py    # --call mode: call request, startup order
├── test_startup.py          # token routing, PUBLIC_URL, env, API errors
└── test_vobiz_number.py     # application create/update + number attach
```

Each test file starts with a `Feature:` docstring describing the area it
covers; each test carries a Gherkin-style `Scenario:` docstring plus a
`Purpose:` line explaining why it exists and what it protects against.

## Adapting for your own integration

Use this suite as scaffolding — swap in your own handler code inside
`proxy.py`, then re-run `pytest` to confirm you haven't broken the
contract with Vobiz or Speechmatics.
