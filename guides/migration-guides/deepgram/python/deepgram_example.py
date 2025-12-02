"""
Deepgram Real-time Streaming Example
Shows how to stream audio to Deepgram for real-time transcription
"""

import os
import time
import threading
from pathlib import Path
from deepgram import DeepgramClient
from deepgram.core.events import EventType
from deepgram.extensions.types.sockets.listen_v1_control_message import ListenV1ControlMessage

from dotenv import load_dotenv

load_dotenv()

def main():
    """Stream audio to Deepgram for real-time transcription"""

    # Initialize the Deepgram client
    api_key = os.getenv("DEEPGRAM_API_KEY")
    if not api_key:
        raise ValueError("DEEPGRAM_API_KEY environment variable not set")

    client = DeepgramClient(api_key=api_key)

    # Path to your audio file
    audio_file_path = Path(__file__).parent.parent / "assets" / "sample.wav"

    print("Starting Deepgram streaming...")

    # Use context manager for the websocket connection with options as parameters
    with client.listen.v1.connect(
        model="nova-3",
        language="en-US",
        smart_format="true",
        diarize="true",
        interim_results="true",
    ) as connection:
        # Define event handlers
        def on_open(event):
            print("Connection opened to Deepgram")

        def on_message(result):
            if hasattr(result, 'channel') and result.channel.alternatives:
                sentence = result.channel.alternatives[0].transcript
                if sentence:
                    if result.is_final:
                        print(f"[FINAL] {sentence}")
                    else:
                        print(f"[INTERIM] {sentence}", end="\r")

        def on_error(error):
            print(f"Error: {error}")

        def on_close(event):
            print("\nConnection closed")

        # Register event handlers
        connection.on(EventType.OPEN, on_open)
        connection.on(EventType.MESSAGE, on_message)
        connection.on(EventType.ERROR, on_error)
        connection.on(EventType.CLOSE, on_close)

        # Start listening for events in a background thread
        listen_thread = threading.Thread(target=connection.start_listening, daemon=True)
        listen_thread.start()

        try:
            with open(audio_file_path, "rb") as audio_file:
                # Read and send audio in chunks
                chunk_size = 8000  # 8KB chunks
                while True:
                    chunk = audio_file.read(chunk_size)
                    if not chunk:
                        break

                    connection.send_media(chunk)
                    time.sleep(0.1)  # Simulate real-time streaming

            # Signal end of audio and wait for final results
            connection.send_control(ListenV1ControlMessage(type="CloseStream"))
            time.sleep(2)

        except FileNotFoundError:
            print(f"Error: Audio file '{audio_file_path}' not found")
        except Exception as e:
            print(f"Error during streaming: {e}")

if __name__ == "__main__":
    main()
