/**
 * Demo functions for the Voice API Explorer.
 *
 * Each demo showcases a different aspect of the Speechmatics Voice/RT API.
 */

const {
  runSession,
  printMsg,
  header,
  subheader,
  audioFormatBlock,
  sleep,
} = require("./core");

// =============================================================================
// DEMO 1: RT Mode - Basic Transcription
// =============================================================================

async function demoRtBasic(apiKey, server, pcm, sr) {
  header("Demo 1: RT Mode - Real-Time Transcription");
  console.log("  Mode:     RT (no profile)");
  console.log("  Endpoint: /v2");
  console.log(
    "  Shows:    AddPartialTranscript, AddTranscript, confidence scores,",
  );
  console.log(
    "            punctuation, EndOfUtterance, RecognitionStarted",
  );
  console.log();

  const config = {
    transcription_config: {
      language: "en",
      enable_partials: true,
      operating_point: "enhanced",
    },
    audio_format: audioFormatBlock(sr),
  };

  await runSession({
    apiKey,
    server,
    wsPath: "/v2",
    config,
    pcm,
    sampleRate: sr,
    onMessage: (msg) => printMsg(msg),
  });
}

// =============================================================================
// DEMO 2: Voice Mode - Single Profile (adaptive)
// =============================================================================

async function demoVoiceSingle(apiKey, server, pcm, sr) {
  header("Demo 2: Voice Mode - Adaptive Profile");
  console.log("  Mode:     Voice");
  console.log("  Endpoint: /v2/agent/adaptive");
  console.log(
    "  Shows:    AddPartialSegment, AddSegment, SpeakerStarted/Ended,",
  );
  console.log(
    "            StartOfTurn, EndOfTurn, SessionMetrics, SpeakerMetrics",
  );
  console.log();

  const config = {
    transcription_config: {
      language: "en",
    },
    audio_format: audioFormatBlock(sr),
  };

  await runSession({
    apiKey,
    server,
    wsPath: "/v2/agent/adaptive",
    config,
    pcm,
    sampleRate: sr,
    onMessage: (msg) => printMsg(msg),
  });
}

// =============================================================================
// DEMO 3: Voice Mode - Profile Comparison
// =============================================================================

async function demoVoiceProfiles(apiKey, server, pcm, sr) {
  header("Demo 3: Voice Mode - Profile Comparison");
  console.log(
    "  Runs the same audio through all four profiles to compare behaviour.",
  );
  console.log("  Profiles are selected via URL path: /v2/agent/{profile}");
  console.log(
    "  Versioning is also supported, e.g. /v2/agent/adaptive:latest",
  );
  console.log();

  const profiles = [
    ["agile", "Fastest response, VAD-based turn detection"],
    ["adaptive", "Adapts to speaker pace and disfluency"],
    ["smart", "Acoustic model for turn completion"],
    ["external", "Client-controlled turn detection"],
  ];

  for (const [profile, desc] of profiles) {
    subheader(`Profile: ${profile} - ${desc}`);
    console.log(`  Endpoint: /v2/agent/${profile}`);
    console.log();

    const config = {
      transcription_config: {
        language: "en",
      },
      audio_format: audioFormatBlock(sr),
    };

    // For external profile, manually trigger end-of-utterance
    let afterFn = null;
    if (profile === "external") {
      afterFn = async (ws) => {
        await sleep(500);
        console.log("    >> Sending ForceEndOfUtterance");
        ws.send(JSON.stringify({ message: "ForceEndOfUtterance" }));
      };
    }

    try {
      await runSession({
        apiKey,
        server,
        wsPath: `/v2/agent/${profile}`,
        config,
        pcm,
        sampleRate: sr,
        onMessage: (msg) => printMsg(msg),
        afterAudioFn: afterFn,
      });
    } catch (e) {
      console.log(`    [Error] ${e.constructor.name}: ${e.message}`);
    }

    console.log();
  }
}

// =============================================================================
// DEMO 4: Voice Mode - Advanced Features
// =============================================================================

async function demoVoiceAdvanced(apiKey, server, pcm, sr) {
  header("Demo 4: Voice Mode - Advanced Features");
  console.log(
    "  Features: enable_diarization, UpdateSpeakerFocus, GetSpeakers,",
  );
  console.log(
    "            ForceEndOfUtterance, SpeakersResult, focus_mode",
  );
  console.log();

  const config = {
    transcription_config: {
      language: "en",
      enable_diarization: true,
    },
    audio_format: audioFormatBlock(sr),
  };

  async function midSessionActions(ws) {
    // 1. Request speaker identification data
    console.log();
    console.log("    >> Sending GetSpeakers");
    ws.send(JSON.stringify({ message: "GetSpeakers" }));
    await sleep(1000);

    // 2. Update speaker focus - retain mode
    console.log(
      "    >> Sending UpdateSpeakerFocus (focus S1, mode=retain)",
    );
    ws.send(
      JSON.stringify({
        message: "UpdateSpeakerFocus",
        speaker_focus: {
          focus_speakers: ["S1"],
          ignore_speakers: [],
          focus_mode: "retain",
        },
      }),
    );
    await sleep(500);

    // 3. Force end of utterance
    console.log("    >> Sending ForceEndOfUtterance");
    ws.send(JSON.stringify({ message: "ForceEndOfUtterance" }));
    await sleep(500);

    // 4. Switch to ignore mode
    console.log(
      "    >> Sending UpdateSpeakerFocus (focus S1, mode=ignore)",
    );
    ws.send(
      JSON.stringify({
        message: "UpdateSpeakerFocus",
        speaker_focus: {
          focus_speakers: ["S1"],
          ignore_speakers: [],
          focus_mode: "ignore",
        },
      }),
    );
    await sleep(300);
  }

  await runSession({
    apiKey,
    server,
    wsPath: "/v2/agent/adaptive",
    config,
    pcm,
    sampleRate: sr,
    onMessage: (msg) => printMsg(msg),
    afterAudioFn: midSessionActions,
  });
}

// =============================================================================
// DEMO 5: Message Control - Include/Exclude
// =============================================================================

async function demoMessageControl(apiKey, server, pcm, sr) {
  header("Demo 5: Message Control - Include/Exclude");

  // --- Part A: Include optional messages ---
  subheader("Part A: Include optional messages");
  console.log(
    "  AudioAdded, SpeechStarted, SpeechEnded are NOT forwarded by default.",
  );
  console.log("  Using message_control.include to opt in.");
  console.log();

  const configInclude = {
    transcription_config: {
      language: "en",
    },
    audio_format: audioFormatBlock(sr),
    message_control: {
      include: ["AudioAdded", "SpeechStarted", "SpeechEnded"],
    },
  };

  await runSession({
    apiKey,
    server,
    wsPath: "/v2/agent/adaptive",
    config: configInclude,
    pcm,
    sampleRate: sr,
    onMessage: (msg) => printMsg(msg, { showOptional: true }),
  });

  // --- Part B: Exclude default messages ---
  subheader("Part B: Exclude default messages");
  console.log(
    "  SpeakerMetrics and SessionMetrics are forwarded by default in Voice mode.",
  );
  console.log("  Using message_control.exclude to opt out.");
  console.log();

  const configExclude = {
    transcription_config: {
      language: "en",
    },
    audio_format: audioFormatBlock(sr),
    message_control: {
      exclude: ["SpeakerMetrics", "SessionMetrics"],
    },
  };

  await runSession({
    apiKey,
    server,
    wsPath: "/v2/agent/agile",
    config: configExclude,
    pcm,
    sampleRate: sr,
    onMessage: (msg) => printMsg(msg),
  });
}

// --- Exports -----------------------------------------------------------------

module.exports = {
  demoRtBasic,
  demoVoiceSingle,
  demoVoiceProfiles,
  demoVoiceAdvanced,
  demoMessageControl,
};
