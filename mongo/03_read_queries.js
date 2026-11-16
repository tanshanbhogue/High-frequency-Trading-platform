// =====================================================================
// 03_read_queries.js - READ operations  (rubric 4: NoSQL feature - Read)
// Run:  mongosh --file mongo/03_read_queries.js
// (or paste one block at a time into an interactive mongosh session)
// =====================================================================
const hft = db.getSiblingDB('HFT_docs');
const show = (title, data) => { print('\n=== ' + title); printjson(data); };

// R1. find with a filter and a projection: all runs of algorithm 2
show('R1. Runs of algorithm 2 (label + metrics only)',
  hft.backtest_results.find({ algorithm_id: 2 }, { _id: 0, run_label: 1, metrics: 1 }).toArray());

// R2. comparison operators: Sharpe ratio above 1.5, best first
show('R2. Sharpe > 1.5',
  hft.backtest_results.find({ 'metrics.sharpe': { $gt: 1.5 } }, { _id: 0, algorithm_name: 1, version: 1, run_label: 1, 'metrics.sharpe': 1 })
    .sort({ 'metrics.sharpe': -1 }).toArray());

// R3. nested field + array queries: runs tagged 'india' that traded INFY
show('R3. tag india AND universe contains INFY',
  hft.backtest_results.find({ tags: 'india', universe: 'INFY' }, { _id: 0, run_label: 1, universe: 1, tags: 1 }).toArray());

// R4. $or / $in: failed OR negative-return runs
show('R4. FAILED or negative return',
  hft.backtest_results.find({ $or: [{ status: 'FAILED' }, { 'metrics.total_return_pct': { $lt: 0 } }] },
    { _id: 0, run_label: 1, status: 1, 'metrics.total_return_pct': 1 }).toArray());

// R5. sort / limit: top 3 returns
show('R5. Top 3 total returns',
  hft.backtest_results.find({}, { _id: 0, run_label: 1, 'metrics.total_return_pct': 1 })
    .sort({ 'metrics.total_return_pct': -1 }).limit(3).toArray());

// R6. count
show('R6. Number of REVIEWED runs', hft.backtest_results.countDocuments({ status: 'REVIEWED' }));

// R7. AGGREGATION: average Sharpe, best return and run count per strategy type
show('R7. Aggregation by strategy_type',
  hft.backtest_results.aggregate([
    { $group: { _id: '$strategy_type', runs: { $sum: 1 }, avg_sharpe: { $avg: '$metrics.sharpe' },
                best_return_pct: { $max: '$metrics.total_return_pct' } } },
    { $project: { _id: 0, strategy_type: '$_id', runs: 1, best_return_pct: 1, avg_sharpe: { $round: ['$avg_sharpe', 2] } } },
    { $sort: { avg_sharpe: -1 } }
  ]).toArray());

// R8. AGGREGATION with $unwind: how many runs use each universe ticker
show('R8. Runs per ticker ($unwind)',
  hft.backtest_results.aggregate([
    { $unwind: '$universe' },
    { $group: { _id: '$universe', runs: { $sum: 1 } } },
    { $sort: { runs: -1, _id: 1 } }, { $limit: 6 }
  ]).toArray());

// R9. AGGREGATION: events per order with the list of event types
show('R9. Event count per order (first 5 orders)',
  hft.order_events.aggregate([
    { $group: { _id: '$order_id', events: { $sum: 1 }, types: { $push: '$event_type' } } },
    { $sort: { _id: 1 } }, { $limit: 5 }
  ]).toArray());

// R10. Query a nested payload field: fills that executed 500+ shares
show('R10. FILL events with payload.executed_quantity >= 500',
  hft.order_events.find({ event_type: 'FILL', 'payload.executed_quantity': { $gte: 500 } },
    { _id: 0, order_id: 1, 'payload.exchange_mic': 1, 'payload.executed_quantity': 1 }).sort({ order_id: 1 }).toArray());

// R11. The full timeline of one order (links to MySQL orders.order_id = 4)
show('R11. Timeline of order 4',
  hft.order_events.find({ order_id: 4 }, { _id: 0, event_type: 1, ts: 1, payload: 1 }).sort({ ts: 1 }).toArray());
