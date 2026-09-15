#!/usr/bin/env bun
/**
 * Repo-level prerequisite checks.
 *
 * This deliberately runs as TypeScript rather than a shell one-liner: on
 * Windows `bun run` uses the Bun Shell, which has no `test` builtin, so a
 * `test -d node_modules && ... || ...` guard silently takes the false branch
 * and still exits 0. A real filesystem check cannot drift that way.
 */
import { existsSync } from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dir, '..')

console.log('Checking shared repo prerequisites...')
console.log(`- bun available (${Bun.version})`)

if (!existsSync(path.join(root, 'node_modules'))) {
  console.error('- root node_modules missing; run bun install')
  process.exit(1)
}
console.log('- workspace dependencies installed')
