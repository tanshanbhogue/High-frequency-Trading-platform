import { NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDb } from '@/lib/mongo';
import { requireRole, bad } from '@/lib/api';

export const dynamic = 'force-dynamic';

const mongoError = (e) => NextResponse.json({ error: 'MongoDB error: ' + e.message }, { status: 503 });
const clean = (d) => ({ ...d, _id: String(d._id) });

// READ  GET /api/mongo/backtests?algorithm_id=2&status=REVIEWED[&stats=1]
export async function GET(request) {
  const { error } = await requireRole();
  if (error) return error;
  try {
    const sp = new URL(request.url).searchParams;
    const filter = {};
    if (sp.get('algorithm_id')) filter.algorithm_id = Number(sp.get('algorithm_id'));
    if (sp.get('status')) filter.status = sp.get('status');
    const docs = await (await getDb()).collection('backtest_results')
      .find(filter, { projection: { equity_curve: 0 } }).sort({ run_at: -1 }).toArray();
    if (sp.get('stats')) {
      const by = {};
      for (const d of docs) {
        const s = (by[d.strategy_type] ||= { strategy_type: d.strategy_type, runs: 0, sharpe_sum: 0, best_return_pct: -Infinity });
        s.runs++; s.sharpe_sum += d.metrics.sharpe; s.best_return_pct = Math.max(s.best_return_pct, d.metrics.total_return_pct);
      }
      return NextResponse.json(Object.values(by).map((s) => ({
        strategy_type: s.strategy_type, runs: s.runs, avg_sharpe: Math.round((s.sharpe_sum / s.runs) * 100) / 100, best_return_pct: s.best_return_pct,
      })).sort((a, b) => b.avg_sharpe - a.avg_sharpe));
    }
    return NextResponse.json(docs.map(clean));
  } catch (e) { return mongoError(e); }
}

// CREATE POST - ADMIN and TRADER
export async function POST(request) {
  const { error } = await requireRole(['ADMIN', 'TRADER']);
  if (error) return error;
  try {
    const b = await request.json();
    if (!b.algorithm_id || !b.algorithm_name || !b.run_label) return bad('algorithm_id, algorithm_name and run_label are required');
    const doc = {
      algorithm_id: Number(b.algorithm_id), algorithm_name: b.algorithm_name, version: b.version || '1.0',
      strategy_type: b.strategy_type || 'Unknown', run_label: b.run_label, run_at: new Date(),
      universe: b.universe || [], parameters: b.parameters || {},
      metrics: { total_return_pct: Number(b.total_return_pct || 0), sharpe: Number(b.sharpe || 0), max_drawdown_pct: Number(b.max_drawdown_pct || 0), win_rate_pct: Number(b.win_rate_pct || 0), num_trades: Number(b.num_trades || 0) },
      equity_curve: [], tags: b.tags || [], status: 'COMPLETED', notes: b.notes || '',
    };
    const r = await (await getDb()).collection('backtest_results').insertOne(doc);
    return NextResponse.json({ _id: String(r.insertedId) }, { status: 201 });
  } catch (e) { return mongoError(e); }
}

// UPDATE PATCH { id, status?, notes?, add_tag?, remove_tag? } - ADMIN and TRADER
export async function PATCH(request) {
  const { error } = await requireRole(['ADMIN', 'TRADER']);
  if (error) return error;
  try {
    const b = await request.json();
    if (!b.id || !ObjectId.isValid(b.id)) return bad('A valid id is required');
    const update = {};
    const set = {};
    if (b.status) set.status = b.status;
    if (b.notes !== undefined) set.notes = String(b.notes);
    if (Object.keys(set).length) update.$set = set;
    if (b.add_tag) update.$addToSet = { tags: String(b.add_tag) };
    if (b.remove_tag) update.$pull = { tags: String(b.remove_tag) };
    if (!Object.keys(update).length) return bad('Nothing to update');
    const r = await (await getDb()).collection('backtest_results').updateOne({ _id: new ObjectId(b.id) }, update);
    return NextResponse.json({ matched: r.matchedCount, modified: r.modifiedCount });
  } catch (e) { return mongoError(e); }
}

// DELETE /api/mongo/backtests?id=... - ADMIN only
export async function DELETE(request) {
  const { error } = await requireRole(['ADMIN']);
  if (error) return error;
  try {
    const id = new URL(request.url).searchParams.get('id');
    if (!id || !ObjectId.isValid(id)) return bad('A valid id is required');
    const r = await (await getDb()).collection('backtest_results').deleteOne({ _id: new ObjectId(id) });
    return NextResponse.json({ deleted: r.deletedCount });
  } catch (e) { return mongoError(e); }
}
