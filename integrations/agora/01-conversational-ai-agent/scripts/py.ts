#!/usr/bin/env bun
/**
 * Cross-platform Python launcher.
 *
 * Package scripts cannot hardcode an interpreter name: macOS and Linux ship
 * `python3` (often with no `python` at all), while Windows ships `python` and
 * the `py` launcher. This resolves the first interpreter that satisfies the
 * project's minimum version and forwards every argument to it.
 *
 *   bun scripts/py.ts server/scripts/setup_env.py --check
 */
import { spawnSync } from 'node:child_process'

const MIN: [number, number] = [3, 10]

/** Candidate interpreters as [command, ...leadingArgs]. */
const CANDIDATES: string[][] = [
  ...(process.env.QUICKSTART_PYTHON ? [[process.env.QUICKSTART_PYTHON]] : []),
  ['python3'],
  ['python3.14'],
  ['python3.13'],
  ['python3.12'],
  ['python3.11'],
  ['python3.10'],
  ['python'],
  ['py', '-3'],
]

const PROBE = 'import sys; print("%d.%d" % sys.version_info[:2])'

function versionOf(candidate: string[]): [number, number] | null {
  const [command, ...leading] = candidate
  let probe: ReturnType<typeof spawnSync>
  try {
    probe = spawnSync(command, [...leading, '-c', PROBE], { encoding: 'utf8' })
  } catch {
    return null
  }
  if (probe.status !== 0 || !probe.stdout) return null
  const [major, minor] = probe.stdout.trim().split('.').map(Number)
  if (!Number.isFinite(major) || !Number.isFinite(minor)) return null
  return [major, minor]
}

function selectPython(): string[] {
  const tried: string[] = []
  for (const candidate of CANDIDATES) {
    const version = versionOf(candidate)
    if (!version) {
      tried.push(candidate.join(' '))
      continue
    }
    if (version[0] > MIN[0] || (version[0] === MIN[0] && version[1] >= MIN[1])) {
      return candidate
    }
    tried.push(`${candidate.join(' ')} (Python ${version[0]}.${version[1]})`)
  }
  console.error(
    `Python ${MIN[0]}.${MIN[1]}+ is required but was not found on PATH.\n` +
      `Tried: ${tried.join(', ') || 'nothing'}\n` +
      'Install Python 3.10 or newer, or set QUICKSTART_PYTHON to a supported interpreter.',
  )
  process.exit(1)
}

const [command, ...leading] = selectPython()
const result = spawnSync(command, [...leading, ...process.argv.slice(2)], { stdio: 'inherit' })
if (result.error) {
  console.error(`Failed to run ${command}: ${result.error.message}`)
  process.exit(1)
}
if (result.signal) {
  console.error(`${command} terminated by signal ${result.signal}`)
  process.exit(1)
}
process.exit(result.status ?? 1)
