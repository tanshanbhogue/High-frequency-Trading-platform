// =====================================================================
// 01_create_collections.js - MongoDB database, collections, validators, indexes
// Rubric 2: NoSQL database creation
// Run:  mongosh --file mongo/01_create_collections.js
//
// Database : HFT_docs
// Why MongoDB? These two data sets are document-shaped and flexible:
//   backtest_results - nested parameters/metrics and an equity-curve array
//                      whose shape differs per strategy
//   order_events     - an event log where each event type carries
//                      different fields (fill vs. route vs. cancel ...)
// They link to MySQL by id (algorithm_id -> algorithms, order_id -> orders).
// =====================================================================

const hft = db.getSiblingDB('HFT_docs');

// Start clean so the script can be re-run (this only touches HFT_docs).
hft.backtest_results.drop();
hft.order_events.drop();

// Creates a collection with a $jsonSchema validator. Real MongoDB always accepts
// it; some Mongo-compatible servers do not support validators, in which case we
// fall back to a plain collection and say so.
function makeCollection(name, validator) {
  try {
    hft.createCollection(name, { validator: validator });
  } catch (e) {
    print('WARNING: validator not supported by this server (' + String(e.message).slice(0, 60) + '...) - created ' + name + ' without validator');
    hft.createCollection(name);
  }
}

// ---------------------------------------------------------------------
// backtest_results : one document per backtest run of an algorithm
// ---------------------------------------------------------------------
makeCollection('backtest_results', {
    $jsonSchema: {
      bsonType: 'object',
      required: ['algorithm_id', 'algorithm_name', 'strategy_type', 'run_label', 'run_at', 'metrics', 'status'],
      properties: {
        algorithm_id:   { bsonType: ['int', 'long', 'double'], minimum: 1, description: 'MySQL algorithms.algorithm_id' },
        algorithm_name: { bsonType: 'string' },
        version:        { bsonType: 'string' },
        strategy_type:  { bsonType: 'string' },
        run_label:      { bsonType: 'string' },
        run_at:         { bsonType: 'date' },
        universe:       { bsonType: 'array', items: { bsonType: 'string' } },
        parameters:     { bsonType: 'object' },
        metrics: {
          bsonType: 'object',
          required: ['total_return_pct', 'sharpe', 'max_drawdown_pct', 'num_trades'],
          properties: {
            total_return_pct: { bsonType: ['double', 'int', 'long'] },
            sharpe:           { bsonType: ['double', 'int', 'long'] },
            max_drawdown_pct: { bsonType: ['double', 'int', 'long'] },
            win_rate_pct:     { bsonType: ['double', 'int', 'long'], minimum: 0, maximum: 100 },
            num_trades:       { bsonType: ['int', 'long', 'double'], minimum: 0 }
          }
        },
        equity_curve: { bsonType: 'array' },
        tags:         { bsonType: 'array', items: { bsonType: 'string' } },
        status:       { enum: ['COMPLETED', 'REVIEWED', 'FAILED'] },
        notes:        { bsonType: 'string' }
      }
    }
});
hft.backtest_results.createIndex({ algorithm_id: 1, run_at: -1 });
hft.backtest_results.createIndex({ 'metrics.sharpe': -1 });
hft.backtest_results.createIndex({ strategy_type: 1 });
hft.backtest_results.createIndex({ tags: 1 });

// ---------------------------------------------------------------------
// order_events : append-style log of what happened to an order
// ---------------------------------------------------------------------
makeCollection('order_events', {
    $jsonSchema: {
      bsonType: 'object',
      required: ['order_id', 'event_type', 'ts'],
      properties: {
        order_id:   { bsonType: ['int', 'long', 'double'], minimum: 1, description: 'MySQL orders.order_id' },
        event_type: { enum: ['ORDER_CREATED', 'ROUTED', 'FILL', 'FILLED', 'CANCELLED', 'REJECTED', 'NOTE'] },
        ts:         { bsonType: 'date' },
        source:     { enum: ['web', 'algo', 'exchange', 'system'] },
        payload:    { bsonType: 'object' }
      }
    }
});
hft.order_events.createIndex({ order_id: 1, ts: 1 });
hft.order_events.createIndex({ event_type: 1 });

print('Created collections in HFT_docs:');
printjson(hft.getCollectionNames());
