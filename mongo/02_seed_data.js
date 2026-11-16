// =====================================================================
// 02_seed_data.js - demo data linked to the MySQL ids
// Rubric 2: NoSQL database creation (seed data)
// Run:  mongosh --file mongo/02_seed_data.js     (after 01_create_collections.js)
// Re-running this file on its own restores the original data after the
// update/delete demos (it empties both collections first).
// =====================================================================

const hft = db.getSiblingDB('HFT_docs');
hft.backtest_results.deleteMany({});
hft.order_events.deleteMany({});

// ---- mirror of the MySQL algorithms table (id -> name, version, strategy) ----
const ALGO = {
  1: ['AlphaMaker', '1.0', 'Market Making'],       2: ['AlphaMaker', '2.1', 'Market Making'],
  3: ['MomentumX', '1.3', 'Momentum Trading'],      4: ['MeanRevert Pro', '2.0', 'Mean Reversion'],
  5: ['StatArb Engine', '1.5', 'Statistical Arbitrage'], 6: ['PairsTrader', '1.1', 'Pairs Trading'],
  7: ['CrossVenue Arb', '3.0', 'Arbitrage'],        8: ['VWAP Slicer', '2.2', 'VWAP'],
  9: ['TWAP Executor', '1.0', 'TWAP'],              10: ['MomentumX', '2.0', 'Momentum Trading'],
  11: ['PairsTrader', '2.0', 'Pairs Trading'],      12: ['LiquiditySeeker', '1.0', 'Market Making']
};

// [algorithm_id, label, run date, universe, parameters, return%, sharpe, maxDD%, win%, trades, status, tags, notes]
const RUNS = [
  [1,  'Q4-2023 baseline',      '2023-12-20', ['INFY', 'TCS'],          { quote_width_bps: 4, inventory_limit: 5000 },   6.4, 1.21, -3.1, 54.2, 1840, 'COMPLETED', ['market-making', 'india'], 'First production-like run.'],
  [2,  'Q1-2024 adaptive',      '2024-03-02', ['INFY', 'RELIANCE'],     { quote_width_bps: 3, adaptive: true },          9.8, 1.86, -2.4, 57.9, 2210, 'REVIEWED',  ['market-making', 'india', 'adaptive'], 'Adaptive spread improved Sharpe.'],
  [2,  'Q1-2024 wide spread',   '2024-03-04', ['INFY', 'RELIANCE'],     { quote_width_bps: 8, adaptive: false },         4.1, 0.74, -4.9, 51.0, 1320, 'COMPLETED', ['market-making', 'india'], 'Control run with a fixed wide spread.'],
  [3,  'US tech breakout',      '2023-09-15', ['MSFT', 'AAPL', 'NVDA'], { lookback: 20, volume_mult: 1.8 },              14.2, 1.33, -8.7, 46.5, 410,  'REVIEWED',  ['momentum', 'us-tech'], 'Strong in trending weeks only.'],
  [3,  'US tech chop regime',   '2023-11-10', ['MSFT', 'AAPL', 'NVDA'], { lookback: 20, volume_mult: 1.8 },              -3.6, -0.42, -11.2, 39.8, 388, 'COMPLETED', ['momentum', 'us-tech', 'weak'], 'Loses in sideways markets.'],
  [4,  'Banking mean reversion','2023-10-05', ['HDFCBANK', 'INFY'],     { window: 30, entry_z: 2.0, exit_z: 0.3 },       7.7, 1.52, -3.8, 61.3, 690,  'COMPLETED', ['mean-reversion', 'india'], 'Works best on liquid large caps.'],
  [5,  'US large-cap basket',   '2023-11-22', ['MSFT', 'GOOGL', 'AAPL'], { coint_window: 60, entry_z: 2.2 },             11.3, 2.04, -2.9, 63.7, 520,  'REVIEWED',  ['stat-arb', 'us-tech', 'high-sharpe'], 'Best Sharpe of all runs so far.'],
  [6,  'UK banks pair',         '2023-12-12', ['HSBA', 'BP.'],          { hedge_ratio: 0.83, entry_z: 1.9 },             5.2, 0.97, -4.4, 55.1, 275,  'COMPLETED', ['pairs', 'uk'], ''],
  [7,  'NSE vs BSE latency arb','2024-01-25', ['HDFCBANK', 'INFY', 'TCS'], { min_edge_bps: 1.5, max_hold_ms: 250 },       12.9, 2.41, -1.2, 71.4, 9100, 'REVIEWED',  ['arbitrage', 'india', 'high-sharpe'], 'Edge decays quickly after 09:45 IST.'],
  [7,  'NASDAQ vs Xetra arb',   '2024-02-14', ['MSFT', 'AAPL'],         { min_edge_bps: 2.5, max_hold_ms: 400 },         3.8, 0.88, -2.0, 58.2, 1450, 'COMPLETED', ['arbitrage', 'cross-border'], 'FX noise reduces the edge.'],
  [8,  'VWAP slicing, Infosys', '2023-06-08', ['INFY'],                 { slices: 20, participation_pct: 8 },            0.6, 0.31, -0.5, 52.0, 2000, 'COMPLETED', ['vwap', 'execution', 'india'], 'Measured as slippage vs VWAP.'],
  [9,  'TWAP trial',            '2024-04-16', ['SPY', 'QQQ'],           { slices: 12, window_min: 60 },                  0.4, 0.22, -0.4, 50.4, 960,  'COMPLETED', ['twap', 'execution'], 'Testing status: more data needed.'],
  [10, 'MomentumX 2.0 ML filter','2024-06-08', ['NVDA', 'TSLA', 'MSFT'], { lookback: 15, ml_threshold: 0.62 },            16.8, 1.71, -7.1, 48.9, 372,  'COMPLETED', ['momentum', 'us-tech', 'ml'], 'Rewrite with ML signal filter.'],
  [11, 'Kalman pairs prototype','2024-07-20', ['HSBA', 'BP.'],          { kalman_q: 0.001, entry_z: 1.8 },               2.2, 0.51, -5.6, 53.3, 140,  'FAILED',    ['pairs', 'uk', 'prototype'], 'Diverged on the 2024-02 data window.'],
  [12, 'Thin-book rebate capture','2024-08-06', ['NIFTYBEES', 'SPY'],   { post_only: true, max_order_size: 200 },         8.9, 1.44, -3.3, 59.6, 3300, 'COMPLETED', ['market-making', 'etf'], 'Rebate income dominates PnL.'],
  [4,  'Banking MR, wider band','2023-10-19', ['HDFCBANK'],             { window: 30, entry_z: 2.6, exit_z: 0.3 },       4.9, 1.05, -2.7, 64.8, 301,  'COMPLETED', ['mean-reversion', 'india'], 'Fewer, higher-quality trades.']
];

const runDocs = RUNS.map(([aid, label, date, universe, params, ret, sharpe, dd, win, trades, status, tags, notes], idx) => {
  const [name, version, strategy] = ALGO[aid];
  // Deterministic 10-point equity curve ending at the run's total return
  const curve = [];
  for (let i = 0; i < 10; i++) {
    const wiggle = Math.sin(i * 1.7 + aid + idx) * 0.004;
    const equity = 100000 * (1 + (ret / 100) * (i / 9) + (i > 0 && i < 9 ? wiggle : 0));
    curve.push({ day: i + 1, equity: Math.round(equity * 100) / 100 });
  }
  const start = new Date(date + 'T00:00:00Z');
  const end = new Date(start.getTime() + 9 * 86400000);
  return {
    algorithm_id: aid, algorithm_name: name, version: version, strategy_type: strategy,
    run_label: label, run_at: new Date(date + 'T12:00:00Z'),
    period: { start: start, end: end },
    universe: universe, parameters: params,
    metrics: { total_return_pct: ret, sharpe: sharpe, max_drawdown_pct: dd, win_rate_pct: win, num_trades: trades },
    equity_curve: curve, tags: tags, status: status, notes: notes
  };
});
hft.backtest_results.insertMany(runDocs);

// ---------------------------------------------------------------------
// order_events - mirrors the MySQL orders / routes / trades of the demo data
// spec: [order_id, side, qty, created, final, routes[[mic,qty]], fills[[mic,qty,price,time]], source]
// ---------------------------------------------------------------------
const D = '2024-03-15T';
const ORDERS = [
  [1,  'BUY',  1000, D + '03:50:00', 'FILLED',   [['XNSE', 1000]], [['XNSE', 400, 1651.30, '03:50:01.120'], ['XNSE', 350, 1651.50, '03:52:10.450'], ['XNSE', 250, 1651.45, '04:05:12.000']], 'algo'],
  [2,  'BUY',  500,  D + '03:52:00', null,       [['XNSE', 500]],  [['XNSE', 200, 4048.75, '03:55:00.300'], ['XNSE', 100, 4049.00, '04:10:00.000']], 'web'],
  [3,  'SELL', 2000, D + '04:00:30', 'FILLED',   [['XNSE', 2000]], [['XNSE', 1200, 2951.30, '04:00:30.500'], ['XNSE', 800, 2951.10, '04:00:30.900']], 'algo'],
  [4,  'BUY',  150,  D + '14:30:00', 'FILLED',   [['XNAS', 100], ['XETR', 50]], [['XNAS', 60, 419.88, '14:30:01.000'], ['XNAS', 40, 419.90, '14:30:01.800'], ['XETR', 50, 388.20, '14:30:02.400']], 'algo'],
  [5,  'BUY',  200,  D + '14:31:00', null,       [['XNAS', 150], ['XETR', 50]], [['XNAS', 90, 174.95, '14:31:05.200'], ['XNAS', 30, 175.00, '14:45:00.000']], 'web'],
  [6,  'SELL', 100,  D + '14:32:00', 'FILLED',   [['XNAS', 100]],  [['XNAS', 60, 885.40, '14:32:03.100'], ['XNAS', 40, 885.10, '14:32:04.700']], 'algo'],
  [7,  'BUY',  1000, D + '04:30:00', 'FILLED',   [['XNSE', 600], ['XBOM', 400]], [['XNSE', 350, 1440.30, '04:30:00.400'], ['XNSE', 250, 1440.35, '04:30:00.700'], ['XBOM', 400, 1440.45, '04:30:00.900']], 'algo'],
  [8,  'SELL', 1000, D + '04:30:02', 'FILLED',   [['XNSE', 550], ['XBOM', 450]], [['XNSE', 550, 1440.20, '04:30:02.300'], ['XBOM', 450, 1440.05, '04:30:02.800']], 'algo'],
  [9,  'SELL', 100,  D + '14:40:00', null,       [], [], 'web'],
  [10, 'BUY',  800,  D + '09:00:00', null,       [['XLON', 500], ['XHKG', 300]], [['XLON', 300, 6.58, '09:05:00.100'], ['XLON', 200, 6.59, '09:20:00.000']], 'algo'],
  [11, 'SELL', 200,  '2024-03-14T05:00:00', 'CANCELLED', [['XNSE', 200]], [], 'web'],
  [12, 'BUY',  500,  D + '04:31:00', 'REJECTED', [['XNSE', 500]], [], 'algo'],
  [13, 'BUY',  150,  D + '14:35:00', 'FILLED',   [['XNYS', 150]],  [['XNYS', 100, 520.30, '14:35:02.100'], ['XNYS', 50, 520.45, '14:35:04.000']], 'web'],
  [14, 'BUY',  300,  D + '14:36:00', null,       [['XNAS', 300]],  [], 'web'],
  [15, 'BUY',  3000, D + '03:46:00', null,       [['XNSE', 2000], ['XBOM', 1000]], [['XNSE', 900, 1650.70, '03:47:10.100'], ['XBOM', 800, 1650.95, '03:50:20.600'], ['XNSE', 700, 1650.90, '05:30:00.000']], 'algo'],
  [16, 'BUY',  80,   D + '14:34:00', 'FILLED',   [['XNAS', 80]],   [['XNAS', 80, 149.85, '14:34:01.500']], 'algo'],
  [17, 'BUY',  75,   D + '14:41:00', 'CANCELLED', [], [], 'algo']
];

const events = [];
for (const [id, side, qty, created, final, routes, fills, src] of ORDERS) {
  const day = created.slice(0, 11);
  events.push({ order_id: id, event_type: 'ORDER_CREATED', ts: new Date(created + 'Z'), source: src,
                payload: { side: side, quantity: qty, channel: src === 'algo' ? 'algorithm' : 'manual' } });
  for (const [mic, rq] of routes) {
    events.push({ order_id: id, event_type: 'ROUTED', ts: new Date(new Date(created + 'Z').getTime() + 100), source: 'system',
                  payload: { exchange_mic: mic, routed_quantity: rq } });
  }
  for (const [mic, fq, price, t] of fills) {
    events.push({ order_id: id, event_type: 'FILL', ts: new Date(day + t + 'Z'), source: 'exchange',
                  payload: { exchange_mic: mic, executed_quantity: fq, price: price, liquidity: fq >= 500 ? 'sweep' : 'passive' } });
  }
  if (final === 'FILLED') {
    const last = fills[fills.length - 1][3];
    events.push({ order_id: id, event_type: 'FILLED', ts: new Date(day + last + 'Z'), source: 'system', payload: { total_quantity: qty } });
  } else if (final === 'CANCELLED') {
    events.push({ order_id: id, event_type: 'CANCELLED', ts: new Date(new Date(created + 'Z').getTime() + 3600000), source: 'web',
                  payload: { reason: 'Cancelled by trader before execution' } });
  } else if (final === 'REJECTED') {
    events.push({ order_id: id, event_type: 'REJECTED', ts: new Date(new Date(created + 'Z').getTime() + 1000), source: 'exchange',
                  payload: { reason: 'Price outside circuit-limit band', code: 'E1042' } });
  }
}
events.push({ order_id: 5, event_type: 'NOTE', ts: new Date('2024-03-15T14:50:00Z'), source: 'web',
              payload: { text: 'GTC order - will keep working tomorrow', author: 'Emily Carter' } });
hft.order_events.insertMany(events);

print('backtest_results: ' + hft.backtest_results.countDocuments({}));
print('order_events    : ' + hft.order_events.countDocuments({}));
