import { NextResponse } from 'next/server';
import { getDb } from '@/lib/mongo';
import { requireRole, bad } from '@/lib/api';

export const dynamic = 'force-dynamic';

// GET /api/mongo/events?order_id=4 - the order's event timeline from MongoDB
export async function GET(request) {
  const { error } = await requireRole();
  if (error) return error;
  try {
    const orderId = Number(new URL(request.url).searchParams.get('order_id'));
    if (!orderId) return bad('order_id is required');
    const docs = await (await getDb()).collection('order_events').find({ order_id: orderId }).sort({ ts: 1 }).toArray();
    return NextResponse.json(docs.map((d) => ({ ...d, _id: String(d._id) })));
  } catch (e) {
    return NextResponse.json({ error: 'MongoDB error: ' + e.message }, { status: 503 });
  }
}
