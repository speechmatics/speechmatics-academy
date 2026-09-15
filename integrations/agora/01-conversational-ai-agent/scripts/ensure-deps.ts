#!/usr/bin/env bun
/**
 * Install workspace dependencies only when they are missing.
 *
 * The shell form of this guard (`test -d node_modules || bun install`) cannot
 * be used: Bun Shell on Windows has no `test` builtin, so the check silently
 * takes the false branch and still exits 0.
 */
import { existsSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import path from 'node:path'

const root = path.resolve(import.meta.dir, '..')

if (existsSync(path.join(root, 'node_modules'))) {
  process.exit(0)
}

console.log('Installing workspace dependencies...')
const result = spawnSync('bun', ['install'], { cwd: root, stdio: 'inherit' })
process.exit(result.status ?? 1)
