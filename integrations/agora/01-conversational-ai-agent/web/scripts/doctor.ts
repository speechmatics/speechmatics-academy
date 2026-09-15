function fail(message: string): never {
  console.error(message)
  process.exit(1)
}

const backendUrl = process.env.AGENT_BACKEND_URL
if (!backendUrl?.trim()) {
  fail(
    'Missing AGENT_BACKEND_URL. The web app proxies /api/* requests to the Python backend and cannot serve them in-process.',
  )
}

try {
  const parsed = new URL(backendUrl)
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('unsupported protocol')
  }
} catch {
  fail('AGENT_BACKEND_URL must be a valid http(s) URL.')
}

console.log(`Doctor checks passed for Python-backed web proxy mode (${backendUrl})`)
