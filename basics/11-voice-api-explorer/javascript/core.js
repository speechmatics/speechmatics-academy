/**
 * Core infrastructure for the Voice API Explorer.
 *
 * Audio utilities, WebSocket session runner, and message formatter.
 * Shared by demos.js and main.js.
 */

const WebSocket = require("ws");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

// --- Constants ---------------------------------------------------------------

const DEFAULT_SERVER = "wss://preview.rt.speechmatics.com";
const MIC_SAMPLE_RATE = 16000; // Mic recording sample rate (Hz)
const REPLAY_CHUNK_MS = 100; // Replay chunk size for streaming (ms)
const PACING = 4.0; // Replay audio at Nx real-time speed
const state = { debug: false }; // Mutable — set via --debug flag from CLI

// --- Utilities ---------------------------------------------------------------

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// --- Audio Utilities ---------------------------------------------------------

function reportRecording(pcm, sampleRate) {
  const duration = pcm.length / (sampleRate * 2);
  console.log(
    `  Recorded ${duration.toFixed(1)}s of audio (${sampleRate}Hz, 16-bit mono)`,
  );
  if (duration < 0.5) {
    console.log(
      "  Warning: Very short recording. Check your microphone is working.",
    );
  }
}

function findDataChunk(buf) {
  let offset = 36;
  while (offset < buf.length - 8) {
    if (buf.toString("ascii", offset, offset + 4) === "data") {
      const size = buf.readUInt32LE(offset + 4);
      return { offset: offset + 8, size };
    }
    offset += 8 + buf.readUInt32LE(offset + 4);
  }
  return null;
}

function hasMicSupport() {
  // Windows: native MCI API via compiled C# helper — always available
  if (process.platform === "win32") return true;
  // macOS/Linux: requires node-record-lpcm16 + SoX
  try {
    require("node-record-lpcm16");
    return true;
  } catch {
    return false;
  }
}

/**
 * Record audio from the microphone.
 *
 * Platform strategy:
 *  - Windows: compiled C# helper using native MCI API (winmm.dll) — no external deps
 *  - macOS/Linux: node-record-lpcm16 + SoX
 *
 * Both paths return { pcm: Buffer, sampleRate: number }
 */
function recordAudio(sampleRate = MIC_SAMPLE_RATE) {
  if (process.platform === "win32") {
    return recordAudioWindows(sampleRate);
  }
  return recordAudioSox(sampleRate);
}

/** Windows: record mic using MCI API via compiled C# helper (no external deps) */
function recordAudioWindows(sampleRate = MIC_SAMPLE_RATE) {
  const { execSync, spawn } = require("child_process");

  return new Promise((resolve, reject) => {
    const ts = Date.now();
    const tmpDir = process.env.TEMP || process.env.TMP || ".";
    const tmpFile = path.join(tmpDir, `mic_${ts}.wav`);
    const stopFile = path.join(tmpDir, `mic_${ts}.stop`);

    // Compile a small C# recorder exe if not cached. Uses csc.exe from .NET
    // Framework (always available on Windows). Avoids PowerShell Add-Type
    // which can be blocked by security policies.
    const exeFile = path.join(__dirname, ".mic_recorder.exe");

    if (!fs.existsSync(exeFile)) {
      console.log("  Compiling mic recorder (one-time)...");
      const csFile = path.join(tmpDir, `mic_recorder_${ts}.cs`);
      fs.writeFileSync(csFile, MIC_RECORDER_CS);

      // Find csc.exe
      const cscPaths = [
        "C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe",
        "C:\\Windows\\Microsoft.NET\\Framework\\v4.0.30319\\csc.exe",
      ];
      const csc = cscPaths.find((p) => fs.existsSync(p));
      if (!csc) {
        fs.unlinkSync(csFile);
        reject(new Error(
          "Cannot find csc.exe (.NET Framework compiler). " +
          "Use --audio to provide a WAV file instead.",
        ));
        return;
      }

      try {
        execSync(
          `"${csc}" /nologo /target:exe /out:"${exeFile}" "${csFile}"`,
          { stdio: "pipe" },
        );
      } catch (e) {
        reject(new Error(`Failed to compile mic recorder: ${e.stderr?.toString().trim() || e.message}`));
        return;
      } finally {
        try { fs.unlinkSync(csFile); } catch {}
      }
    }

    console.log("  Preparing microphone...");

    const proc = spawn(exeFile, [tmpFile, stopFile], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stderr = "";
    proc.stderr.on("data", (d) => { stderr += d.toString(); });

    // Parse actual sample rate from stdout, show recording prompt
    let actualRate = sampleRate;
    let prompted = false;
    proc.stdout.on("data", (d) => {
      const s = d.toString();
      const match = s.match(/RECORDING:(\d+)/);
      if (match && !prompted) {
        prompted = true;
        actualRate = parseInt(match[1], 10);
        if (actualRate !== sampleRate) {
          console.log(`  (Using ${actualRate}Hz — closest supported rate)`);
        }
        console.log("  Recording... speak now, then press Enter to stop.\n");
      }
    });

    // When user presses Enter, create the stop signal file
    const rl = readline.createInterface({ input: process.stdin });
    rl.once("line", () => {
      rl.close();
      try { fs.writeFileSync(stopFile, "stop"); } catch {}
    });

    proc.on("error", (err) => {
      reject(new Error(`Failed to run mic recorder: ${err.message}`));
    });

    proc.on("close", (code) => {
      try { fs.unlinkSync(stopFile); } catch {}

      if (code !== 0) {
        const errMsg = stderr.trim() || `exit code ${code}`;
        reject(new Error(`Mic recording failed: ${errMsg}`));
        return;
      }

      try {
        // MCI saves as WAV — extract PCM from the data chunk
        const buf = fs.readFileSync(tmpFile);
        fs.unlinkSync(tmpFile);

        const dataChunk = findDataChunk(buf);
        if (!dataChunk) {
          reject(new Error("Recorded WAV has no data chunk"));
          return;
        }
        const pcm = buf.subarray(dataChunk.offset, dataChunk.offset + dataChunk.size);

        reportRecording(pcm, actualRate);
        resolve({ pcm, sampleRate: actualRate });
      } catch (e) {
        reject(new Error(`Failed to read recording: ${e.message}`));
      }
    });
  });
}

// C# source for the mic recorder helper. Compiled once by csc.exe, cached as
// .mic_recorder.exe. Uses Windows MCI API (winmm.dll) — simple open/record/
// stop/save with no callbacks or buffer management.
const MIC_RECORDER_CS = `
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class MicRecorder {
    [DllImport("winmm.dll", CharSet = CharSet.Ansi)]
    static extern int mciSendStringA(string command, StringBuilder rv, int rvLen, IntPtr hwnd);

    static int Mci(string cmd) {
        StringBuilder sb = new StringBuilder(256);
        return mciSendStringA(cmd, sb, sb.Capacity, IntPtr.Zero);
    }

    static int Main(string[] args) {
        if (args.Length < 2) {
            Console.Error.WriteLine("Usage: mic_recorder <outWav> <stopFile>");
            return 1;
        }
        string outWav = args[0];
        string stopFile = args[1];

        int r = Mci("open new type waveaudio alias mic");
        if (r != 0) {
            Console.Error.WriteLine("No audio input device found (MCI error " + r + ").");
            return 1;
        }

        // Try sample rates in preference order
        int[] rates = {16000, 22050, 44100, 48000, 11025};
        int usedRate = 0;
        foreach (int rate in rates) {
            r = Mci("set mic bitspersample 16 channels 1 samplespersec " + rate);
            if (r != 0) continue;
            r = Mci("record mic");
            if (r == 0) { usedRate = rate; break; }
        }

        if (usedRate == 0) {
            Mci("close mic");
            Console.Error.WriteLine("No supported recording format found. Check your microphone.");
            return 1;
        }

        // Signal to Node which rate succeeded
        Console.Out.WriteLine("RECORDING:" + usedRate);
        Console.Out.Flush();

        // Poll for stop signal
        while (!File.Exists(stopFile)) {
            Thread.Sleep(50);
        }

        Mci("stop mic");
        r = Mci("save mic " + (char)34 + outWav + (char)34);
        Mci("close mic");
        try { File.Delete(stopFile); } catch {}

        if (r != 0) {
            Console.Error.WriteLine("Failed to save recording (MCI error " + r + ").");
            return 1;
        }
        return 0;
    }
}
`;

/** Unix/macOS: record mic using node-record-lpcm16 + SoX */
function recordAudioSox(sampleRate = MIC_SAMPLE_RATE) {
  const record = require("node-record-lpcm16");

  return new Promise((resolve, reject) => {
    const chunks = [];
    let errored = false;

    const recording = record.record({
      sampleRate,
      channels: 1,
      audioType: "raw",
      recorder: "sox",
    });

    const stream = recording.stream();
    stream.on("data", (chunk) => chunks.push(chunk));

    // Catch both stream errors and child process spawn errors (e.g. SoX not installed)
    const handleError = (err) => {
      if (errored) return;
      errored = true;
      if (err.code === "ENOENT") {
        console.log();
        console.log("Error: SoX is not installed or not found in PATH.");
        console.log();
        console.log("  Install SoX:");
        console.log("    macOS:    brew install sox");
        console.log("    Linux:    sudo apt install sox");
        console.log();
        console.log("  Or use --audio to provide a WAV file instead:");
        console.log(
          "    node main.js rt --audio ../assets/sample_mono.wav",
        );
        process.exit(1);
      }
      reject(err instanceof Error ? err : new Error(String(err || "Unknown recording error")));
    };

    stream.on("error", handleError);
    // The child process error fires before the stream error for spawn failures
    if (recording.process) {
      recording.process.on("error", handleError);
      recording.process.on("close", (code) => {
        if (code && code !== 0 && !errored) {
          errored = true;
          reject(new Error(`SoX exited with code ${code}. Is your microphone connected and accessible?`));
        }
      });
    }

    console.log("  Recording... speak now, then press Enter to stop.\n");

    const rl = readline.createInterface({ input: process.stdin });
    rl.once("line", () => {
      recording.stop();
      rl.close();
      const pcm = Buffer.concat(chunks);
      reportRecording(pcm, sampleRate);
      resolve({ pcm, sampleRate });
    });
  });
}

function readWav(filePath) {
  const buf = fs.readFileSync(filePath);

  if (buf.toString("ascii", 0, 4) !== "RIFF") {
    throw new Error("Not a WAV file (missing RIFF header)");
  }
  if (buf.toString("ascii", 8, 12) !== "WAVE") {
    throw new Error("Not a WAV file (missing WAVE marker)");
  }

  const audioFormat = buf.readUInt16LE(20);
  const numChannels = buf.readUInt16LE(22);
  const sampleRate = buf.readUInt32LE(24);
  const bitsPerSample = buf.readUInt16LE(34);

  if (audioFormat !== 1) {
    throw new Error(
      `Expected PCM format (audioFormat=1), got ${audioFormat}. ` +
        "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav",
    );
  }
  if (numChannels !== 1) {
    throw new Error(
      `Expected mono audio, got ${numChannels} channels. ` +
        "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav",
    );
  }
  if (bitsPerSample !== 16) {
    throw new Error(
      `Expected 16-bit audio, got ${bitsPerSample}-bit. ` +
        "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav",
    );
  }

  // Scan for 'data' chunk (handles extended headers / metadata)
  const dataChunk = findDataChunk(buf);
  if (!dataChunk) {
    throw new Error("WAV file has no data chunk");
  }
  const pcm = buf.subarray(dataChunk.offset, dataChunk.offset + dataChunk.size);

  const duration = pcm.length / (sampleRate * 2);
  console.log(
    `  Audio: ${path.basename(filePath)} (${duration.toFixed(1)}s, ${sampleRate}Hz, 16-bit mono)`,
  );
  return { pcm, sampleRate };
}

function* iterChunks(pcm, sampleRate, chunkMs = REPLAY_CHUNK_MS) {
  const chunkBytes = Math.floor((sampleRate * 2 * chunkMs) / 1000);
  for (let i = 0; i < pcm.length; i += chunkBytes) {
    yield pcm.subarray(i, i + chunkBytes);
  }
}

// --- Session Runner ----------------------------------------------------------

async function runSession({
  apiKey,
  server,
  wsPath,
  config,
  pcm,
  sampleRate,
  onMessage,
  afterAudioFn = null,
}) {
  const url = `${server}${wsPath}`;
  const messages = [];

  if (state.debug) {
    console.log(`  [DEBUG] URL: ${url}`);
  }

  return new Promise((resolve, reject) => {
    let resolved = false;
    let recognitionStartedResolve;
    const recognitionStartedPromise = new Promise((r) => {
      recognitionStartedResolve = r;
    });

    const ws = new WebSocket(url, {
      headers: { Authorization: `Bearer ${apiKey}` },
      handshakeTimeout: 10000,
    });

    // --- Receiver (event-driven) ---
    ws.on("message", (data, isBinary) => {
      if (isBinary || resolved) return;
      let msg;
      try {
        msg = JSON.parse(data.toString());
      } catch {
        return;
      }

      const msgType = msg.message || "";
      messages.push(msg);

      if (state.debug) {
        console.log(
          `  [DEBUG] << ${msgType}: ${JSON.stringify(msg).slice(0, 200)}`,
        );
      }

      if (msgType === "RecognitionStarted") {
        recognitionStartedResolve();
      }

      onMessage(msg);

      if (msgType === "EndOfTranscript") {
        if (!resolved) {
          resolved = true;
          ws.close();
          resolve(messages);
        }
      }
    });

    // --- Sender (async, runs after open) ---
    ws.on("open", async () => {
      const startMsg = { message: "StartRecognition", ...config };
      if (state.debug) {
        console.log(
          `  [DEBUG] Sending: ${JSON.stringify(startMsg, null, 2)}`,
        );
      }
      ws.send(JSON.stringify(startMsg));

      // Wait for RecognitionStarted
      const timeout = setTimeout(() => {
        if (!resolved) {
          console.log(
            "  [Timeout] RecognitionStarted not received within 10s",
          );
          resolved = true;
          ws.close();
          resolve(messages);
        }
      }, 10000);

      await recognitionStartedPromise;
      clearTimeout(timeout);

      // Stream audio chunks at paced rate
      const chunkDelay = REPLAY_CHUNK_MS / PACING; // ms
      for (const chunk of iterChunks(pcm, sampleRate)) {
        if (ws.readyState !== WebSocket.OPEN) break;
        ws.send(chunk);
        await sleep(chunkDelay);
      }

      // Mid-session actions (ForceEOU, UpdateSpeakerFocus, etc.)
      if (afterAudioFn) {
        await afterAudioFn(ws);
      }

      // Signal end of audio
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ message: "EndOfStream", last_seq_no: 0 }));
      }
    });

    ws.on("error", (err) => {
      if (err.message && err.message.includes("401")) {
        console.log("  [ConnectionFailed] HTTP 401");
        console.log("  Check your SPEECHMATICS_API_KEY is valid.");
      } else if (err.message && err.message.includes("Unexpected server response")) {
        const match = err.message.match(/(\d{3})/);
        const code = match ? match[1] : "?";
        console.log(`  [ConnectionFailed] HTTP ${code}`);
        if (code === "401") {
          console.log("  Check your SPEECHMATICS_API_KEY is valid.");
        }
      } else {
        console.log(`  [NetworkError] ${err.message}`);
      }
      if (!resolved) {
        resolved = true;
        resolve(messages);
      }
    });

    ws.on("close", (code, reason) => {
      if (!resolved) {
        if (code !== 1000 && code !== 1005) {
          console.log(
            `  [ConnectionClosed] code=${code} reason=${reason.toString()}`,
          );
        }
        resolved = true;
        resolve(messages);
      }
    });
  });
}

// --- Message Formatter -------------------------------------------------------

// ANSI colour codes
const C = {
  RESET: "\x1b[0m",
  BOLD: "\x1b[1m",
  DIM: "\x1b[2m",
  GREEN: "\x1b[32m",
  YELLOW: "\x1b[33m",
  CYAN: "\x1b[36m",
  MAGENTA: "\x1b[35m",
  RED: "\x1b[31m",
  ORANGE: "\x1b[38;5;208m",
  BLUE: "\x1b[34m",
  WHITE: "\x1b[37m",
};

// Optional message types - only shown when the demo explicitly opts in
const OPTIONAL_MSG_TYPES = new Set([
  "AudioAdded",
  "SpeechStarted",
  "SpeechEnded",
  "EndOfTurnPrediction",
  "SmartTurnResult",
  "Diagnostics",
]);

function fmt(v) {
  return typeof v === "number" ? v.toFixed(2) : String(v);
}

function translationText(msg) {
  let text = (msg.metadata || {}).transcript || "";
  if (!text) {
    text = (msg.results || []).map((r) => r.content || "").join(" ").trim();
  }
  return text;
}

function printMsg(msg, { indent = 4, showOptional = false } = {}) {
  const p = " ".repeat(indent);
  const mt = msg.message || "unknown";

  if (!showOptional && OPTIONAL_MSG_TYPES.has(mt)) {
    return;
  }

  if (mt === "RecognitionStarted") {
    const sid = (msg.id || "?").slice(0, 20);
    const lang = (msg.language_pack_info || {}).language_description || "?";
    const ver = msg.orchestrator_version || "";
    console.log(
      `${p}${C.BLUE}${C.BOLD}[RecognitionStarted]${C.RESET}${C.BLUE} session=${sid}... lang=${lang}${C.RESET}`,
    );
    if (ver) {
      console.log(`${p}${C.BLUE}  orchestrator: ${ver}${C.RESET}`);
    }
  } else if (mt === "AddPartialTranscript") {
    const text = (msg.metadata || {}).transcript || "";
    if (text.trim()) {
      console.log(`${p}${C.YELLOW}[Partial]     ${text}${C.RESET}`);
    }
  } else if (mt === "AddTranscript") {
    const text = (msg.metadata || {}).transcript || "";
    if (text.trim()) {
      const results = msg.results || [];
      const words = results.filter((r) => r.type === "word");
      if (words.length > 0) {
        const confs = words.map((w) => w.alternatives[0].confidence);
        const avg = confs.reduce((a, b) => a + b, 0) / confs.length;
        console.log(
          `${p}${C.GREEN}${C.BOLD}[Final]       ${text}  (avg confidence: ${avg.toFixed(2)})${C.RESET}`,
        );
      } else {
        console.log(
          `${p}${C.GREEN}${C.BOLD}[Final]       ${text}${C.RESET}`,
        );
      }
    }
  } else if (mt === "AddPartialTranslation") {
    const lang = msg.language || "?";
    const text = translationText(msg);
    if (text.trim()) {
      console.log(
        `${p}${C.YELLOW}[PartialTr:${lang}] ${text}${C.RESET}`,
      );
    } else {
      console.log(
        `${p}${C.YELLOW}[PartialTr:${lang}] (raw: ${JSON.stringify(msg).slice(0, 120)})${C.RESET}`,
      );
    }
  } else if (mt === "AddTranslation") {
    const lang = msg.language || "?";
    const text = translationText(msg);
    if (text.trim()) {
      console.log(
        `${p}${C.GREEN}${C.BOLD}[Translation:${lang}] ${text}${C.RESET}`,
      );
    } else {
      console.log(
        `${p}${C.GREEN}${C.BOLD}[Translation:${lang}] (raw: ${JSON.stringify(msg).slice(0, 120)})${C.RESET}`,
      );
    }
  } else if (mt === "AddPartialSegment") {
    for (const seg of msg.segments || []) {
      const text = seg.text || "";
      if (text.trim()) {
        const spk = seg.speaker_id || "?";
        const ann = seg.annotation || [];
        const annS = ann.length > 0 ? `  [${ann.join(", ")}]` : "";
        console.log(
          `${p}${C.YELLOW}[PartialSeg]  ${spk}: ${text}${annS}${C.RESET}`,
        );
      }
    }
  } else if (mt === "AddSegment") {
    for (const seg of msg.segments || []) {
      const text = seg.text || "";
      const spk = seg.speaker_id || "?";
      const ann = seg.annotation || [];
      const eou = seg.is_eou || false;
      const meta = seg.metadata || {};
      const t0 = meta.start_time || 0;
      const t1 = meta.end_time || 0;
      const annS =
        ann.length > 0
          ? `  ${C.DIM}[${ann.join(", ")}]${C.RESET}`
          : "";
      const eouS = eou ? ` ${C.CYAN}(EOU)${C.RESET}` : "";
      console.log(
        `${p}${C.GREEN}${C.BOLD}[Segment]     ${spk}: ${text} (${t0.toFixed(2)}-${t1.toFixed(2)}s)${C.RESET}${annS}${eouS}`,
      );
    }
  } else if (mt === "SpeakerStarted") {
    const spk = msg.speaker_id || "?";
    const t = (msg.metadata || {}).start_time || msg.time || "?";
    console.log(
      `${p}${C.CYAN}[SpeakerStarted] ${spk} at ${fmt(t)}s${C.RESET}`,
    );
  } else if (mt === "SpeakerEnded") {
    const spk = msg.speaker_id || "?";
    const t = (msg.metadata || {}).end_time || msg.time || "?";
    console.log(
      `${p}${C.CYAN}[SpeakerEnded]   ${spk} at ${fmt(t)}s${C.RESET}`,
    );
  } else if (mt === "StartOfTurn") {
    console.log(
      `${p}${C.CYAN}${C.BOLD}[StartOfTurn]  turn_id=${msg.turn_id || "?"}${C.RESET}`,
    );
  } else if (mt === "EndOfTurn") {
    console.log(
      `${p}${C.CYAN}${C.BOLD}[EndOfTurn]    turn_id=${msg.turn_id || "?"}${C.RESET}`,
    );
  } else if (mt === "EndOfUtterance") {
    const meta = msg.metadata || {};
    console.log(
      `${p}${C.CYAN}[EndOfUtterance] ${fmt(meta.start_time ?? "?")}s - ${fmt(meta.end_time ?? "?")}s${C.RESET}`,
    );
  } else if (mt === "SessionMetrics") {
    const total = msg.total_time_str || msg.total_time || "?";
    const proc = msg.processing_time || "?";
    const byt = msg.total_bytes || "?";
    console.log(
      `${p}${C.MAGENTA}[SessionMetrics]  time=${total} processing=${proc}s bytes=${byt}${C.RESET}`,
    );
  } else if (mt === "SpeakerMetrics") {
    for (const spk of msg.speakers || []) {
      const sid = spk.speaker_id || "?";
      const wc = spk.word_count || 0;
      const vol = spk.volume || 0;
      const last = spk.last_heard || 0;
      console.log(
        `${p}${C.MAGENTA}[SpeakerMetrics]  ${sid}: words=${wc} vol=${vol.toFixed(1)} last=${last.toFixed(2)}s${C.RESET}`,
      );
    }
  } else if (mt === "SpeakersResult") {
    const speakers = msg.speakers || msg;
    console.log(
      `${p}${C.MAGENTA}[SpeakersResult]  ${JSON.stringify(speakers).slice(0, 200)}${C.RESET}`,
    );
  } else if (mt === "AudioAdded") {
    const seq = msg.seq_no || "?";
    console.log(`${p}${C.DIM}[AudioAdded]   seq_no=${seq}${C.RESET}`);
  } else if (mt === "SpeechStarted") {
    const t = (msg.metadata || {}).start_time || "?";
    const prob = msg.probability || "?";
    console.log(
      `${p}${C.WHITE}[SpeechStarted]  at ${fmt(t)}s  probability=${prob}${C.RESET}`,
    );
  } else if (mt === "SpeechEnded") {
    const meta = msg.metadata || {};
    const prob = msg.probability || "?";
    const dur = msg.transition_duration_ms || "?";
    console.log(
      `${p}${C.WHITE}[SpeechEnded]    ${fmt(meta.start_time ?? "?")}-${fmt(meta.end_time ?? "?")}s  prob=${prob}  transition=${dur}ms${C.RESET}`,
    );
  } else if (mt === "EndOfTurnPrediction") {
    const wait = msg.predicted_wait || "?";
    console.log(
      `${p}${C.WHITE}[EndOfTurnPrediction] predicted_wait=${fmt(wait)}s${C.RESET}`,
    );
  } else if (mt === "SmartTurnResult") {
    console.log(
      `${p}${C.WHITE}[SmartTurnResult] ${JSON.stringify(msg).slice(0, 140)}${C.RESET}`,
    );
  } else if (mt === "AudioEventStarted") {
    const etype = msg.type || msg.event || "?";
    console.log(
      `${p}${C.CYAN}[AudioEventStarted] type=${etype}${C.RESET}`,
    );
  } else if (mt === "AudioEventEnded") {
    const etype = msg.type || msg.event || "?";
    console.log(
      `${p}${C.CYAN}[AudioEventEnded]   type=${etype}${C.RESET}`,
    );
  } else if (mt === "Info") {
    const itype = msg.type || "";
    const reason = msg.reason || "";
    const extra = msg.quality ? ` quality=${msg.quality}` : "";
    console.log(
      `${p}${C.BLUE}[Info:${itype}] ${reason}${extra}${C.RESET}`,
    );
  } else if (mt === "Warning") {
    console.log(
      `${p}${C.ORANGE}${C.BOLD}[Warning] ${msg.reason || msg.type || ""}${C.RESET}`,
    );
  } else if (mt === "Error") {
    console.log(
      `${p}${C.RED}${C.BOLD}[Error] ${msg.reason || msg.type || JSON.stringify(msg)}${C.RESET}`,
    );
  } else if (mt === "EndOfTranscript") {
    console.log(
      `${p}${C.BLUE}${C.BOLD}[EndOfTranscript] Session complete.${C.RESET}`,
    );
  } else if (mt === "Diagnostics") {
    console.log(
      `${p}${C.DIM}[Diagnostics] ${JSON.stringify(msg).slice(0, 140)}${C.RESET}`,
    );
  } else {
    console.log(
      `${p}${C.DIM}[${mt}] ${JSON.stringify(msg).slice(0, 140)}${C.RESET}`,
    );
  }
}

// --- Helpers -----------------------------------------------------------------

function header(title) {
  console.log(`\n${"=".repeat(80)}`);
  console.log(`  ${title}`);
  console.log(`${"=".repeat(80)}\n`);
}

function subheader(title) {
  console.log(`\n${"─".repeat(60)}`);
  console.log(`  ${title}`);
  console.log(`${"─".repeat(60)}`);
}

function audioFormatBlock(sampleRate) {
  return {
    type: "raw",
    encoding: "pcm_s16le",
    sample_rate: sampleRate,
  };
}

// --- Exports -----------------------------------------------------------------

module.exports = {
  DEFAULT_SERVER,
  MIC_SAMPLE_RATE,
  state,
  sleep,
  hasMicSupport,
  recordAudio,
  readWav,
  runSession,
  printMsg,
  header,
  subheader,
  audioFormatBlock,
};
