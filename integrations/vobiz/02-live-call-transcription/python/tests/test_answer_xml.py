"""
Feature: Answer XML builder (_build_answer_xml)

    When a call comes in, Vobiz fetches our /answer endpoint and runs
    the VobizXML we return. The response has to contain exactly the
    right elements in the right order:

      <Response>
        <Stream audioTrack="both" contentType="audio/x-l16;rate=16000">
          wss://.../vobiz/<token>
        </Stream>
        <Speak>...</Speak>
        <Dial callerId="<Vobiz number>" timeout="30">
          <Number>+E164</Number>
        </Dial>
      </Response>

    Malformed XML is not an HTTP error at Vobiz: it accepts the 200,
    then drops the call. These tests pin the shape so refactors can't
    sneak a regression in.
"""

from xml.etree import ElementTree as ET

from proxy import VOBIZ_CONTENT_TYPE, _build_answer_xml

STREAM_URL = "wss://tunnel.example.dev/vobiz/abc123"
# +44 7700 900xxx is Ofcom's reserved drama range - never a real subscriber.
FORWARD_TO = "+447700900123"
CALLER_ID = "+447700900456"


def _parse(body: bytes) -> ET.Element:
    return ET.fromstring(body)


def test_answer_xml_returns_bytes():
    """
    Scenario: Return type is bytes, not str
        Given any valid stream URL and numbers
         When _build_answer_xml is invoked
         Then the returned object is a `bytes` instance

    Purpose:
        The /answer handler stores this value verbatim as the HTTP
        response body and sets Content-Length from `len(...)`.
    """
    assert isinstance(_build_answer_xml(STREAM_URL, FORWARD_TO, CALLER_ID), bytes)


def test_answer_xml_root_is_response():
    """
    Scenario: Document root element
        Given the answer XML for any inputs
         When it is parsed as XML
         Then the root element's tag is "Response"
    """
    root = _parse(_build_answer_xml(STREAM_URL, FORWARD_TO, CALLER_ID))
    assert root.tag == "Response"


def test_stream_forks_both_tracks_to_the_proxy():
    """
    Scenario: The <Stream> that forks the call audio
        Given the answer XML for a specific stream URL
         When the document is parsed
         Then the first element is a <Stream>
          And its text content is that stream URL verbatim
          And audioTrack is "both"
          And contentType is the L16/16 kHz format the proxy decodes
          And bidirectional and keepCallAlive are not set

    Purpose:
        The WebSocket URL is the element's text, not an attribute.
        audioTrack="both" is what forks caller and callee into separate
        tracks. A one-way stream does not block, which is what lets
        Vobiz go on to <Dial>: bidirectional="true" cannot carry both
        tracks, and keepCallAlive would hold the call on the stream.
    """
    root = _parse(_build_answer_xml(STREAM_URL, FORWARD_TO, CALLER_ID))

    stream = root[0]
    assert stream.tag == "Stream"
    assert stream.text.strip() == STREAM_URL
    assert stream.attrib["audioTrack"] == "both"
    assert stream.attrib["contentType"] == VOBIZ_CONTENT_TYPE
    assert "bidirectional" not in stream.attrib
    assert "keepCallAlive" not in stream.attrib


def test_dial_bridges_to_the_forward_number_from_the_vobiz_number():
    """
    Scenario: The <Dial> that bridges to the second human
        Given the answer XML for a forwarding number and caller ID
         When the document is parsed
         Then <Dial><Number> holds the forwarding number verbatim
          And Dial's callerId is the Vobiz number
          And Dial sets an explicit ring timeout

    Purpose:
        Without callerId, Vobiz presents the caller's number on the
        second leg, which it cannot do, so the bridge fails and the
        call falls through. The default ring timeout is 120 seconds.
    """
    root = _parse(_build_answer_xml(STREAM_URL, FORWARD_TO, CALLER_ID))

    dial = root.find("./Dial")
    assert dial is not None
    assert dial.find("./Number").text == FORWARD_TO
    assert dial.attrib["callerId"] == CALLER_ID
    assert dial.attrib["timeout"] == "30"


def test_speak_greeting_comes_before_the_dial():
    """
    Scenario: The <Speak> greeting played before the bridge
        Given the answer XML for any inputs
         When the document is parsed
         Then the elements run Stream, Speak, Dial in that order
          And the greeting mentions "transcribed"

    Purpose:
        Callers must be told the call is transcribed, and the greeting
        lands on the transcript, which proves the stream started first.
    """
    root = _parse(_build_answer_xml(STREAM_URL, FORWARD_TO, CALLER_ID))

    assert [child.tag for child in root] == ["Stream", "Speak", "Dial"]
    assert "transcribed" in root.find("./Speak").text.lower()


def test_values_are_xml_escaped():
    """
    Scenario: A stream URL containing a query string
        Given a stream URL with two query parameters joined by "&"
         When the answer XML is built and parsed
         Then it parses, and the URL round-trips unchanged

    Purpose:
        A bare "&" invalidates the document, and Vobiz then drops the
        call with "Invalid Answer XML" in the CDR.
    """
    url = "wss://tunnel.example.dev/vobiz/abc?a=1&b=2"
    root = _parse(_build_answer_xml(url, FORWARD_TO, CALLER_ID))
    assert root[0].text.strip() == url
