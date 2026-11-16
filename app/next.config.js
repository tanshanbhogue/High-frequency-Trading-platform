// Loads the single .env that lives in the repository root (or app/.env) so you
// only keep ONE copy of the configuration.
const fs = require('fs');
const path = require('path');

for (const file of [path.join(__dirname, '.env'), path.join(__dirname, '..', '.env')]) {
  if (fs.existsSync(file)) {
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2];
    }
    break;
  }
}

/** @type {import('next').NextConfig} */
module.exports = {
  reactStrictMode: true,
  experimental: { serverComponentsExternalPackages: ['mysql2', 'mongodb'] },
  // The session secret is needed by the edge middleware too, so inline it.
  env: { JWT_SECRET: process.env.JWT_SECRET || 'dev-only-secret-change-me' },
};
