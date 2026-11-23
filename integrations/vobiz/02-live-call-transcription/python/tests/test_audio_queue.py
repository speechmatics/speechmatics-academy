"""
Feature: AsyncQueueSource

    Speechmatics' AsyncMultiChannelClient reads round-robin from every
    audio source it's handed. If any source ever returns empty bytes it
    interprets that as EOF and tears down the *whole* session - so a
    naive queue-backed source would break the moment Vobiz has a
    momentary lull in packets.

    AsyncQueueSource is the adapter that solves this. It behaves like a
    file:
      - read(n) blocks until at least some data is available (never
        returns short unless we're closing).
      - close() posts an EOF sentinel so pending reads unblock and
        subsequent reads keep returning empty bytes.
      - Late enqueue() calls after close() are silently dropped so
        Vobiz's tail-end frames can't accidentally revive a source.

    These tests pin down that contract so future refactors don't
    regress the "keep the session alive during a phone call" property.
"""

import asyncio

import pytest
from proxy import AsyncQueueSource


async def test_read_returns_enqueued_bytes():
    """
    Scenario: Reading data that has already been enqueued
        Given a fresh AsyncQueueSource
         When five bytes are enqueued
          And read(5) is awaited
         Then the awaited read returns exactly those five bytes

    Purpose:
        Baseline sanity check - if this fails, the queue plumbing is
        broken and nothing else in this file can be trusted.
    """
    src = AsyncQueueSource()

    # Push a frame in synchronously - enqueue is not async.
    src.enqueue(b"hello")

    # read(5) requests five bytes; because we've already enqueued five,
    # it should return immediately without yielding to the event loop.
    assert await src.read(5) == b"hello"


async def test_read_blocks_until_data_arrives():
    """
    Scenario: A read that arrives before any data
        Given a fresh AsyncQueueSource with no data enqueued
         When read(4) is started as a background task
         Then the task is still pending after a short sleep
         When four bytes are subsequently enqueued
         Then the task completes and returns those bytes

    Purpose:
        Confirms the blocking-read invariant. If read() returned early
        with empty bytes instead of blocking, Speechmatics would see
        that as EOF and drop the session mid-call.
    """
    src = AsyncQueueSource()

    # Start the read as an independent task so we can observe its state
    # before any producer has fed the queue.
    reader = asyncio.create_task(src.read(4))

    # A short yield gives the reader a chance to make progress *if it
    # were going to*. If read() were non-blocking, `reader.done()` would
    # already be True here.
    await asyncio.sleep(0.05)
    assert not reader.done(), "read() should block on an empty queue"

    # Now supply the data - the reader should unblock and return it.
    src.enqueue(b"data")
    assert await asyncio.wait_for(reader, timeout=1.0) == b"data"


async def test_close_yields_eof():
    """
    Scenario: Reading from a closed, empty source
        Given a fresh AsyncQueueSource with no data enqueued
          And close() has been called
         When read(10) is awaited
         Then the read returns empty bytes (EOF signal)

    Purpose:
        Once we tear a call down we want the multi-channel SDK to see
        EOF and stop reading. This proves the explicit shutdown path
        works.
    """
    src = AsyncQueueSource()

    # No enqueue - queue is empty when we close.
    src.close()

    # An empty bytes result is the EOF sentinel the SDK looks for.
    assert await src.read(10) == b""


async def test_close_drains_buffer_then_yields_eof():
    """
    Scenario: Closing while unread data is still queued
        Given an AsyncQueueSource with three bytes enqueued
          And close() has been called
         When read(10) is awaited
         Then the read returns the three buffered bytes (short read)
         When a second read(10) is awaited
         Then it returns empty bytes (EOF)

    Purpose:
        Guarantees no data loss on shutdown - if Vobiz's tail frames
        are still in the queue when we close, Speechmatics still gets
        to transcribe them before the session ends.
    """
    src = AsyncQueueSource()
    src.enqueue(b"abc")

    # Close while data is still buffered.
    src.close()

    # First read consumes what was in the queue - a short read is
    # correct here because there's less data than requested.
    assert await src.read(10) == b"abc"

    # Only after the buffer is drained do subsequent reads hit EOF.
    assert await src.read(10) == b""


async def test_enqueue_after_close_is_dropped():
    """
    Scenario: Frames arriving after the source has been closed
        Given a closed AsyncQueueSource
         When a "late" frame is enqueued
          And read(10) is awaited
         Then the read returns empty bytes (the late frame is not delivered)

    Purpose:
        Defends against race conditions where Vobiz sends a `media`
        event a few ms after the session closed. Without this guard, the late
        frame could hold read() open indefinitely.
    """
    src = AsyncQueueSource()
    src.close()

    # Simulate a straggling Vobiz frame arriving after the call ends
    # event has already closed us.
    src.enqueue(b"late frame")

    # Because the source is closed, the enqueue is a no-op - read
    # sees only the EOF sentinel.
    assert await src.read(10) == b""


async def test_read_reassembles_across_multiple_enqueues():
    """
    Scenario: A read that spans multiple queued chunks
        Given an AsyncQueueSource with three 2-byte chunks enqueued
         When read(6) is awaited
         Then the read returns all six bytes concatenated in FIFO order

    Purpose:
        Vobiz delivers audio stream frames roughly every 20 ms; the
        Speechmatics SDK asks for a specific chunk size that likely
        doesn't align with those boundaries. This proves the internal
        buffering stitches chunks together correctly.
    """
    src = AsyncQueueSource()

    # Enqueue three separate 2-byte chunks. Each becomes its own item
    # in the underlying asyncio.Queue.
    src.enqueue(b"aa")
    src.enqueue(b"bb")
    src.enqueue(b"cc")

    # A single read(6) should walk all three items and concatenate
    # them in order.
    assert await src.read(6) == b"aabbcc"


@pytest.mark.parametrize(
    "chunks",
    [
        [b"x" * 640],  # 1 chunk of 640
        [b"x" * 320, b"y" * 320],  # 2 chunks of 320
        [b"a" * 160, b"b" * 160, b"c" * 160, b"d" * 160],  # 4 chunks of 160
    ],
)
async def test_read_at_vobiz_frame_size(chunks):
    """
    Scenario Outline: Reading exactly one Vobiz frame worth of audio
        Given a source pre-loaded with <chunks> that total 640 bytes
         When read(640) is awaited
         Then the returned bytes equal the concatenation of <chunks>

    Purpose:
        The proxy asks Vobiz for 16-bit PCM at 16 kHz, which arrives as
        20 ms frames of exactly 640 bytes. The Speechmatics
        multi-channel SDK is configured to read at that same chunk
        size. This test verifies the source produces clean 640-byte
        reads regardless of how the input is fragmented on the wire.
    """
    src = AsyncQueueSource()

    # Enqueue each chunk independently to simulate how audio stream
    # events might arrive - one per WebSocket message.
    for c in chunks:
        src.enqueue(c)

    # A single 640-byte read is what the SDK issues per source.
    assert await src.read(640) == b"".join(chunks)


async def test_backlog_beyond_the_cap_is_dropped():
    """
    Scenario: Audio arriving much faster than real time
        Given an AsyncQueueSource already holding MAX_QUEUED_FRAMES frames
         When one more frame is enqueued
         Then the queue does not grow
          And close() still delivers EOF after the queued frames

    Purpose:
        Bounds memory if a stream sends audio faster than it is read.
    """
    src = AsyncQueueSource()
    for _ in range(AsyncQueueSource.MAX_QUEUED_FRAMES + 10):
        src.enqueue(b"x")
    assert src._queue.qsize() == AsyncQueueSource.MAX_QUEUED_FRAMES

    src.close()
    data = await src.read(AsyncQueueSource.MAX_QUEUED_FRAMES + 100)
    assert data == b"x" * AsyncQueueSource.MAX_QUEUED_FRAMES
