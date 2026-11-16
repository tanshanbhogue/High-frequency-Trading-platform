// =====================================================================
// 05_delete_operations.js - DELETE operations  (rubric 4: NoSQL feature - Delete)
// Run:  mongosh --file mongo/05_delete_operations.js
// Restore the original data afterwards with:  mongosh --file mongo/02_seed_data.js
// =====================================================================
const hft = db.getSiblingDB('HFT_docs');
const show = (title, data) => { print('\n=== ' + title); printjson(data); };

show('Documents before', { backtest_results: hft.backtest_results.countDocuments({}), order_events: hft.order_events.countDocuments({}) });

// D1. deleteOne: remove a single run by its label
let r = hft.backtest_results.deleteOne({ run_label: 'TWAP trial' });
show('D1. deleteOne -> deleted', r.deletedCount);

// D2. deleteMany with a filter: remove all FAILED runs
r = hft.backtest_results.deleteMany({ status: 'FAILED' });
show('D2. deleteMany status FAILED -> deleted', r.deletedCount);

// D3. deleteMany with a comparison operator: runs with a negative Sharpe ratio
r = hft.backtest_results.deleteMany({ 'metrics.sharpe': { $lt: 0 } });
show('D3. deleteMany Sharpe < 0 -> deleted', r.deletedCount);

// D4. deleteMany on the event log: remove the cancelled/rejected markers of order 17 and 12
r = hft.order_events.deleteMany({ order_id: { $in: [12, 17] }, event_type: { $in: ['CANCELLED', 'REJECTED'] } });
show('D4. deleteMany order_events -> deleted', r.deletedCount);

// D5. TTL index: documents carrying "expire_at" delete themselves automatically.
//     (MongoDB's background task runs about once a minute.)
hft.order_events.createIndex({ expire_at: 1 }, { expireAfterSeconds: 0, name: 'ttl_expire_at' });
hft.order_events.insertOne({ order_id: 1, event_type: 'NOTE', ts: new Date(), source: 'system',
                             payload: { text: 'temporary debug note' }, expire_at: new Date(Date.now() + 60 * 1000) });
show('D5. TTL index created; temporary note inserted (disappears within ~2 minutes)',
     hft.order_events.countDocuments({ expire_at: { $exists: true } }));
hft.order_events.dropIndex('ttl_expire_at');   // remove the TTL index again so the demo stays repeatable
hft.order_events.deleteMany({ expire_at: { $exists: true } });

show('Documents after', { backtest_results: hft.backtest_results.countDocuments({}), order_events: hft.order_events.countDocuments({}) });
