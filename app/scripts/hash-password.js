// Usage: node scripts/hash-password.js <password>
// Prints a bcrypt hash to paste into sql/04_seed_app_users.sql (or an INSERT).
const bcrypt = require('bcryptjs');
const pw = process.argv[2];
if (!pw) { console.error('Usage: node scripts/hash-password.js <password>'); process.exit(1); }
console.log(bcrypt.hashSync(pw, 10));
