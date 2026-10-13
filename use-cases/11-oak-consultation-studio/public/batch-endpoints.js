// Oak 1 supports Batch transcription in EU1 and US1 only.
export const DEFAULT_BATCH_REGION = 'eu';
export const BATCH_ENDPOINTS = Object.freeze({
  eu: 'https://eu1.asr.api.speechmatics.com/v2',
  us: 'https://us1.asr.api.speechmatics.com/v2',
});
