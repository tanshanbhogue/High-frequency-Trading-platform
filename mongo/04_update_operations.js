// =====================================================================
// 04_update_operations.js - UPDATE operations  (rubric 4: NoSQL feature - Update)
// Run:  mongosh --file mongo/04_update_operations.js
// Restore the original data afterwards with:  mongosh --file mongo/02_seed_data.js
// =====================================================================
const hft = db.getSiblingDB('HFT_docs');
const show = (title, data) => { print('\n=== ' + title); printjson(data); };
const label = 'Q1-2024 wide spread';

// U1. updateOne + $set: mark a run as REVIEWED and add a note
let r = hft.backtest_results.updateOne({ run_label: label }, { $set: { status: 'REVIEWED', notes: 'Reviewed: confirms wide spreads lose edge.' } });
show('U1. updateOne $set -> matched/modified', { matched: r.matchedCount, modified: r.modifiedCount });
show('    result', hft.backtest_results.findOne({ run_label: label }, { _id: 0, run_label: 1, status: 1, notes: 1 }));

// U2. $inc: correct the trade count of that run by +10
hft.backtest_results.updateOne({ run_label: label }, { $inc: { 'metrics.num_trades': 10 } });
show('U2. $inc metrics.num_trades (was 1320)', hft.backtest_results.findOne({ run_label: label }, { _id: 0, 'metrics.num_trades': 1 }));

// U3. updateMany + $addToSet: tag every run with Sharpe >= 1.5 as 'top-performer' (no duplicates)
r = hft.backtest_results.updateMany({ 'metrics.sharpe': { $gte: 1.5 } }, { $addToSet: { tags: 'top-performer' } });
show('U3. updateMany $addToSet -> modified', { matched: r.matchedCount, modified: r.modifiedCount });

// U4. $push to an array: append a new day to an equity curve
hft.backtest_results.updateOne({ run_label: label }, { $push: { equity_curve: { day: 11, equity: 104250.0 } } });
show('U4. $push equity_curve (has an 11th point now?)',
  hft.backtest_results.countDocuments({ run_label: label, 'equity_curve.10': { $exists: true } }) === 1);

// U5. $pull: remove a tag from all documents
r = hft.backtest_results.updateMany({ tags: 'weak' }, { $pull: { tags: 'weak' } });
show("U5. $pull tag 'weak' -> modified", { modified: r.modifiedCount });

// U6. $set on a nested document + $rename of a field
hft.backtest_results.updateOne({ run_label: label }, { $set: { 'parameters.quote_width_bps': 6 } });
hft.backtest_results.updateMany({ notes: { $exists: true } }, { $rename: { notes: 'comment' } });
show('U6. nested $set + $rename notes->comment', hft.backtest_results.findOne({ run_label: label }, { _id: 0, parameters: 1, comment: 1 }));

// U7. upsert: update the order's NOTE event or create it when missing
r = hft.order_events.updateOne({ order_id: 9, event_type: 'NOTE' },
  { $set: { ts: new Date(), source: 'web', payload: { text: 'Stop order waiting for trigger price', author: 'Vikram Singh' } } },
  { upsert: true });
show('U7. upsert -> upserted?', { matched: r.matchedCount, upserted: r.upsertedCount });

// U8. update in the order log: annotate every FILL of order 15
r = hft.order_events.updateMany({ order_id: 15, event_type: 'FILL' }, { $set: { 'payload.reviewed': true } });
show('U8. updateMany on order_events -> modified', { modified: r.modifiedCount });
