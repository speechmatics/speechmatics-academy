/**
 * Voice API Explorer - CLI Entry Point
 *
 * Comprehensive demo of the Speechmatics Voice API - a unified WebSocket
 * endpoint for both real-time transcription (RT) and voice agent (Voice) modes.
 *
 * Default input is your microphone - speak, press Enter to stop, then demos
 * replay your recording through each API mode and profile.
 *
 * Usage:
 *     node main.js                     # Interactive menu (mic input)
 *     node main.js rt                  # RT mode transcription
 *     node main.js voice               # Voice mode (adaptive profile)
 *     node main.js profiles            # Compare all voice profiles
 *     node main.js advanced            # Speaker focus, ForceEOU, GetSpeakers
 *     node main.js messages            # Message control include/exclude
 *     node main.js all                 # Run all demos
 *     node main.js rt --audio f.wav    # Use a WAV file instead of mic
 */

const fs = require("fs");
const path = require("path");
const readline = require("readline");

require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

const {
  DEFAULT_SERVER,
  state,
  hasMicSupport,
  recordAudio,
  readWav,
} = require("./core");

const {
  demoRtBasic,
  demoVoiceSingle,
  demoVoiceProfiles,
  demoVoiceAdvanced,
  demoMessageControl,
} = require("./demos");

// =============================================================================
// CLI & Main
// =============================================================================

const DEMOS = new Map([
  ["rt", ["RT Mode - Transcription", demoRtBasic]],
  ["voice", ["Voice Mode - Adaptive Profile", demoVoiceSingle]],
  ["profiles", ["Voice Mode - Profile Comparison", demoVoiceProfiles]],
  ["advanced", ["Voice Mode - Advanced Features", demoVoiceAdvanced]],
  ["messages", ["Message Control - Include/Exclude", demoMessageControl]],
]);

function showMenu() {
  return new Promise((resolve) => {
    console.log();
    console.log("=".repeat(60));
    console.log("  Speechmatics Voice API Explorer");
    console.log("=".repeat(60));
    console.log();
    console.log("  Select a demo to run:");
    console.log();

    let i = 1;
    for (const [key, [title]] of DEMOS) {
      console.log(`    ${i}. [${key}] ${title}`);
      i++;
    }
    console.log(`    ${DEMOS.size + 1}. [all] Run all demos`);
    console.log("    0. Exit");
    console.log();

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    const askChoice = () => {
      rl.question("  Enter number or name: ", (answer) => {
        const choice = answer.trim().toLowerCase();

        if (choice === "0" || choice === "exit") {
          rl.close();
          resolve(null);
          return;
        }
        if (choice === "all" || choice === String(DEMOS.size + 1)) {
          rl.close();
          resolve("all");
          return;
        }

        // Match by number
        if (/^\d+$/.test(choice)) {
          const idx = parseInt(choice, 10) - 1;
          const keys = [...DEMOS.keys()];
          if (idx >= 0 && idx < keys.length) {
            rl.close();
            resolve(keys[idx]);
            return;
          }
        }

        // Match by name
        if (DEMOS.has(choice)) {
          rl.close();
          resolve(choice);
          return;
        }

        console.log("  Invalid choice. Try again.");
        askChoice();
      });
    };

    rl.on("close", () => {
      // Handle Ctrl+C / Ctrl+D
    });

    askChoice();
  });
}

function parseArgs() {
  const args = process.argv.slice(2);
  const result = { demo: null, server: null, audio: null, debug: false };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--server" && args[i + 1]) {
      result.server = args[++i];
    } else if (args[i] === "--audio" && args[i + 1]) {
      result.audio = args[++i];
    } else if (args[i] === "--debug") {
      result.debug = true;
    } else if (args[i] === "--help" || args[i] === "-h") {
      console.log(`
Speechmatics Voice API Explorer - demo all features

Usage:
    node main.js [demo] [options]

Available demos:
  rt            RT mode basic transcription (partials, finals, confidence)
  voice         Voice mode with adaptive profile (segments, turns, metrics)
  profiles      Compare all voice profiles (agile, adaptive, smart, external)
  advanced      Speaker focus, ForceEOU, GetSpeakers, diarization
  messages      Message control include/exclude
  all           Run all demos in sequence

Options:
  --server URL  WebSocket server URL (default: ${DEFAULT_SERVER})
  --audio FILE  Path to a 16-bit mono WAV file. If omitted, records from microphone.
  --debug       Show raw WebSocket URL, StartRecognition payload, and all received messages.
  -h, --help    Show this help message.

Audio input:
  Default is live microphone - speak, press Enter to stop.
  Use --audio to provide a WAV file instead.
`);
      process.exit(0);
    } else if (!args[i].startsWith("-")) {
      result.demo = args[i];
    }
  }

  result.server =
    result.server ||
    process.env.SPEECHMATICS_SERVER ||
    DEFAULT_SERVER;

  return result;
}

async function main() {
  const args = parseArgs();
  state.debug = args.debug;

  // --- Validate API key ---
  const apiKey = process.env.SPEECHMATICS_API_KEY;
  if (!apiKey) {
    console.log("Error: SPEECHMATICS_API_KEY not set");
    console.log("Please set it in your .env file or environment");
    process.exit(1);
  }

  // --- Select demo first (before recording) ---
  let demoKey;
  if (args.demo) {
    demoKey = args.demo.toLowerCase();
  } else {
    demoKey = await showMenu();
  }

  if (demoKey === null) {
    console.log("Exiting.");
    return;
  }

  let keys;
  if (demoKey === "all") {
    keys = [...DEMOS.keys()];
  } else if (DEMOS.has(demoKey)) {
    keys = [demoKey];
  } else {
    console.log(`Unknown demo: ${demoKey}`);
    console.log(`Available: ${[...DEMOS.keys()].join(", ")}, all`);
    process.exit(1);
  }

  // --- Get audio ---
  let pcm, sr;
  if (args.audio) {
    const audioPath = path.resolve(args.audio);
    if (!fs.existsSync(audioPath)) {
      console.log(`Error: Audio file not found: ${audioPath}`);
      process.exit(1);
    }
    try {
      ({ pcm, sampleRate: sr } = readWav(audioPath));
    } catch (e) {
      console.log(`Error: ${e.message}`);
      process.exit(1);
    }
  } else {
    // Microphone mode (default)
    if (!hasMicSupport()) {
      console.log();
      console.log("Error: Microphone recording requires SoX and node-record-lpcm16.");
      console.log();
      console.log("  Install SoX:");
      console.log("    macOS:    brew install sox");
      console.log("    Linux:    sudo apt install sox");
      console.log();
      console.log("  Then: npm install node-record-lpcm16");
      console.log();
      console.log("  Or use --audio to provide a WAV file instead:");
      console.log("    node main.js rt --audio ../assets/sample_mono.wav");
      process.exit(1);
    }

    console.log();
    console.log("=".repeat(60));
    console.log("  Microphone Input");
    console.log("=".repeat(60));
    console.log();
    console.log("  Your recording will be replayed through each demo.");
    console.log("  Tip: speak a few sentences for best results.");
    console.log();

    ({ pcm, sampleRate: sr } = await recordAudio());

    if (pcm.length < sr * 2) {
      console.log("  Error: Recording too short. Please try again.");
      process.exit(1);
    }
  }

  // --- Run ---
  console.log();
  console.log(`  Server: ${args.server}`);

  for (const key of keys) {
    const [, func] = DEMOS.get(key);
    await func(apiKey, args.server, pcm, sr);
  }

  console.log();
  console.log("=".repeat(60));
  console.log("  All demos complete.");
  console.log("=".repeat(60));
}

// --- Entry point ---

process.on("SIGINT", () => {
  console.log("\n  Interrupted. Exiting.");
  process.exit(0);
});

main().catch((err) => {
  console.error(`Fatal error: ${err && err.message ? err.message : err}`);
  if (state.debug && err && err.stack) console.error(err.stack);
  process.exit(1);
});
