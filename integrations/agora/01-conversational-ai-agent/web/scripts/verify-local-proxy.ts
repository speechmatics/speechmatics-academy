import nextConfig from '../next.config'

type Rewrite = {
  source: string
  destination: string
}

type LocalServer = {
  port: number
  stop: (closeActiveConnections?: boolean) => void
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message)
  }
}

function getJson(response: Response) {
  return response.json() as Promise<Record<string, unknown>>
}

async function getRewrites(): Promise<Rewrite[]> {
  const rewrites = nextConfig.rewrites
  assert(typeof rewrites === 'function', 'next.config.ts should define async rewrites()')

  const result = await rewrites()
  if (Array.isArray(result)) {
    return result as Rewrite[]
  }

  return [
    ...((result.beforeFiles ?? []) as Rewrite[]),
    ...((result.afterFiles ?? []) as Rewrite[]),
    ...((result.fallback ?? []) as Rewrite[]),
  ]
}

async function requestViaRewrite(sourceUrl: string, init?: RequestInit) {
  const source = new URL(sourceUrl, 'http://localhost:3000')
  const rewrites = await getRewrites()
  const rewrite = rewrites.find((candidate) => candidate.source === source.pathname)
  assert(rewrite, `Missing rewrite for ${source.pathname}`)

  const target = new URL(rewrite.destination)
  target.search = source.search
  return fetch(target, init)
}

async function withStubBackend<T>(run: (baseUrl: string) => Promise<T>) {
  const bunRuntime = globalThis as typeof globalThis & {
    Bun: {
      serve: (options: {
        port: number
        fetch: (request: Request) => Promise<Response> | Response
      }) => LocalServer
    }
  }

  const handler = async (request: Request) => {
    const url = new URL(request.url)

    if (request.method === 'GET' && url.pathname === '/get_config') {
      return Response.json({
        code: 0,
        data: {
          app_id: 'stub-app-id',
          token: 'stub-token',
          uid: '4321',
          channel_name: 'proxy-channel',
          agent_uid: '9999',
        },
        msg: 'success',
      })
    }

    if (request.method === 'POST' && url.pathname === '/startAgent') {
      const parsedBody = (await request.json()) as { rtcUid?: number; userUid?: number }
      if (parsedBody.rtcUid !== 9999 || parsedBody.userUid !== 4321) {
        return Response.json({ detail: 'unexpected proxied payload' }, { status: 400 })
      }

      return Response.json({
        code: 0,
        data: {
          agent_id: 'agent-proxied',
          channel_name: 'proxy-channel',
          status: 'started',
        },
        msg: 'success',
      })
    }

    if (request.method === 'POST' && url.pathname === '/stopAgent') {
      return Response.json({ code: 0, msg: 'success' })
    }

    return new Response('not found', { status: 404 })
  }

  let server: LocalServer | null = null
  const startPort = 43100
  for (let port = startPort; port < startPort + 20; port += 1) {
    try {
      server = bunRuntime.Bun.serve({ port, fetch: handler })
      break
    } catch {}
  }

  if (!server) {
    throw new Error('Failed to start stub backend on a local port')
  }

  try {
    return await run(`http://localhost:${server.port}`)
  } finally {
    server.stop(true)
  }
}

async function main() {
  const originalBackendUrl = process.env.AGENT_BACKEND_URL

  await withStubBackend(async (backendUrl) => {
    process.env.AGENT_BACKEND_URL = backendUrl

    const configResponse = await requestViaRewrite('/api/get_config?uid=4321&channel=proxy-channel')
    const configBody = await getJson(configResponse)
    assert(configResponse.status === 200, 'GET /api/get_config should proxy successfully')
    assert(configBody.code === 0, 'GET /api/get_config should preserve proxied success payload')
    assert(
      (configBody.data as Record<string, unknown>)?.token === 'stub-token',
      'GET /api/get_config should return proxied token',
    )

    const startResponse = await requestViaRewrite('/api/startAgent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        channelName: 'proxy-channel',
        rtcUid: 9999,
        userUid: 4321,
      }),
    })
    const startBody = await getJson(startResponse)
    assert(startResponse.status === 200, 'POST /api/startAgent should proxy successfully')
    assert(
      (startBody.data as Record<string, unknown>)?.agent_id === 'agent-proxied',
      'POST /api/startAgent should return proxied agent id',
    )

    const stopResponse = await requestViaRewrite('/api/stopAgent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ agentId: 'agent-proxied' }),
    })
    const stopBody = await getJson(stopResponse)
    assert(stopResponse.status === 200, 'POST /api/stopAgent should proxy successfully')
    assert(stopBody.code === 0, 'POST /api/stopAgent should preserve proxied success payload')
  })

  if (originalBackendUrl) {
    process.env.AGENT_BACKEND_URL = originalBackendUrl
  } else {
    process.env.AGENT_BACKEND_URL = ''
  }

  console.log('Local proxy checks passed')
}

await main()
