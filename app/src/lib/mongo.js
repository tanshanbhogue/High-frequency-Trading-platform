// MongoDB client (one shared connection). Used for backtest results and the
// order event log. Everything here fails soft: if MongoDB is not running the
// SQL parts of the app keep working.
import { MongoClient } from 'mongodb';

let clientPromise = globalThis.__hftMongo;

export async function getDb() {
  if (!clientPromise) {
    const client = new MongoClient(process.env.MONGODB_URI || 'mongodb://localhost:27017', {
      serverSelectionTimeoutMS: 2500,
    });
    clientPromise = globalThis.__hftMongo = client.connect().catch((e) => {
      globalThis.__hftMongo = undefined;   // allow a retry on the next request
      throw e;
    });
  }
  const client = await clientPromise;
  return client.db(process.env.MONGODB_DB || 'HFT_docs');
}

// Best-effort write to the order event log; never throws.
export async function logOrderEvent(orderId, eventType, source, payload) {
  try {
    const db = await getDb();
    await db.collection('order_events').insertOne({
      order_id: Number(orderId), event_type: eventType, ts: new Date(), source, payload,
    });
  } catch (e) {
    console.warn('MongoDB event not logged:', e.message);
  }
}
