#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
const webPort = process.env.WEBX68K_WEB_PORT ?? '5299';
const bridgePort = process.env.WEBX68K_BRIDGE_PORT ?? '3099';
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';

const children = [];
let stopping = false;

function start(label, command, args, env = {}) {
  const child = spawn(command, args, {
    cwd: projectRoot,
    env: { ...process.env, ...env },
    stdio: 'inherit',
  });
  children.push({ label, child });
  child.once('exit', (code, signal) => {
    if (stopping) return;
    stopping = true;
    console.error(`[WebX68k] ${label} が終了しました (code=${code ?? 'none'}, signal=${signal ?? 'none'})`);
    for (const entry of children) {
      if (!entry.child.killed) entry.child.kill('SIGTERM');
    }
    process.exitCode = code ?? 1;
  });
}

function stop() {
  if (stopping) return;
  stopping = true;
  for (const entry of children) {
    if (!entry.child.killed) entry.child.kill('SIGTERM');
  }
}

process.on('SIGINT', stop);
process.on('SIGTERM', stop);

start('Webサーバー', npmCommand, [
  'run',
  'dev',
  '--',
  '--host',
  '127.0.0.1',
  '--port',
  webPort,
]);

console.error(`[WebX68k] 確認用URL: http://127.0.0.1:${webPort}/?bridge=${bridgePort}&system=1&run=1`);
console.error('[WebX68k] MCPサーバーはMCPクライアントの登録設定から起動してください。');
console.error('[WebX68k] 終了するには Ctrl-C を押してください。');
