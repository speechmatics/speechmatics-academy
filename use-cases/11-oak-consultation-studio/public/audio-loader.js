// Probe imports separately so a pending or failed file never replaces the player.
export function createAudioLoader(dependencies = {}) {
  const browser = {
    createAudio: () => new Audio(),
    createObjectURL: file => URL.createObjectURL(file),
    revokeObjectURL: url => URL.revokeObjectURL(url),
    setTimeout: (...args) => globalThis.setTimeout(...args),
    clearTimeout: (...args) => globalThis.clearTimeout(...args),
    ...dependencies,
  };
  let pending;

  function cancel() {
    pending?.cancel();
  }

  function load(file) {
    cancel();
    return new Promise((resolve, reject) => {
      let probe;
      let url;
      let timer;
      let settled = false;
      let released = false;
      const current = { cancel: () => finish(null, null) };
      pending = current;

      function release() {
        if (released || !url) return;
        released = true;
        browser.revokeObjectURL(url);
      }

      function cleanup() {
        if (timer != null) browser.clearTimeout(timer);
        if (!probe) return;
        probe.removeEventListener('loadedmetadata', loaded);
        probe.removeEventListener('error', failed);
        probe.pause();
        probe.removeAttribute('src');
        probe.load();
      }

      function finish(error, duration) {
        if (settled) return;
        settled = true;
        if (pending === current) pending = null;
        cleanup();
        if (error) { release(); reject(error); }
        else if (duration === null) { release(); resolve(null); }
        else resolve({ url, duration, release });
      }

      function loaded() {
        const duration = Number.isFinite(probe.duration) && probe.duration > 0
          ? probe.duration : file?.recordedDuration;
        if (Number.isFinite(duration) && duration > 0) finish(null, duration);
        else finish(new Error('This file has no readable duration. Try a WAV or MP3 file.'));
      }

      function failed() {
        finish(new Error('This audio cannot be played in this browser. Try a WAV or MP3 file.'));
      }

      try {
        probe = browser.createAudio();
        url = browser.createObjectURL(file);
        probe.preload = 'metadata';
        probe.addEventListener('loadedmetadata', loaded);
        probe.addEventListener('error', failed);
        timer = browser.setTimeout(() => finish(new Error('This file took too long to load. Try a smaller WAV or MP3 file.')), 12000);
        probe.src = url;
        probe.load();
      } catch (error) {
        finish(error instanceof Error ? error : new Error('This audio could not be loaded. Try a WAV or MP3 file.'));
      }
    });
  }

  return { load, cancel };
}
