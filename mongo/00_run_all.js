// =====================================================================
// 00_run_all.js - create + seed the MongoDB side in one command
// Run from the REPOSITORY ROOT:   mongosh --file mongo/00_run_all.js
// (paths are relative to the folder you run it from)
// Safe to re-run: it drops and recreates the two collections.
// =====================================================================
load('mongo/01_create_collections.js');
load('mongo/02_seed_data.js');
