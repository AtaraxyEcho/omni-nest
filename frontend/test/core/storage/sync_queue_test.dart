import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/storage/local_database.dart';
import 'package:omninest/core/storage/sync_queue.dart';

void main() {
  late LocalDatabase db;
  late SyncQueue queue;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    queue = SyncQueue(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue adds operation with pending status', () async {
    final id = await queue.enqueue(
      type: 'file.favorite',
      payload: '{"fileId": "abc"}',
    );
    expect(id, greaterThan(0));
    final ops = await queue.dequeue();
    expect(ops, hasLength(1));
    expect(ops.first.type, 'file.favorite');
    expect(ops.first.status, 'pending');
  });

  test('dequeue returns operations in FIFO order', () async {
    await queue.enqueue(type: 'op1', payload: '{}');
    await queue.enqueue(type: 'op2', payload: '{}');
    await queue.enqueue(type: 'op3', payload: '{}');
    final ops = await queue.dequeue(limit: 2);
    expect(ops, hasLength(2));
    expect(ops.first.type, 'op1');
    expect(ops.last.type, 'op2');
  });

  test('markCompleted sets status and syncedAt', () async {
    final id = await queue.enqueue(type: 'test', payload: '{}');
    await queue.markCompleted(id);
    final ops = await db.select(db.syncOperations).get();
    expect(ops.first.status, 'completed');
    expect(ops.first.syncedAt, isNotNull);
  });

  test('markFailed increments retryCount', () async {
    final id = await queue.enqueue(type: 'test', payload: '{}');
    await queue.markFailed(id);
    await queue.markFailed(id);
    final ops = await db.select(db.syncOperations).get();
    expect(ops.first.status, 'failed');
    expect(ops.first.retryCount, 2);
  });

  test('retryFailed resets failed ops to pending', () async {
    final id = await queue.enqueue(type: 'test', payload: '{}');
    await queue.markFailed(id);
    await queue.retryFailed();
    final ops = await db.select(db.syncOperations).get();
    expect(ops.first.status, 'pending');
  });

  test('retryFailed does not retry ops exceeding maxRetries', () async {
    final id = await queue.enqueue(type: 'test', payload: '{}');
    for (var i = 0; i < 4; i++) {
      await queue.markFailed(id);
    }
    await queue.retryFailed(maxRetries: 3);
    final ops = await db.select(db.syncOperations).get();
    expect(ops.first.status, 'failed');
  });

  test('pendingCount returns correct count', () async {
    await queue.enqueue(type: 'a', payload: '{}');
    await queue.enqueue(type: 'b', payload: '{}');
    final id = await queue.enqueue(type: 'c', payload: '{}');
    await queue.markCompleted(id);
    expect(await queue.pendingCount(), 2);
  });

  test('clearCompleted removes only completed ops', () async {
    await queue.enqueue(type: 'a', payload: '{}');
    final id = await queue.enqueue(type: 'b', payload: '{}');
    await queue.markCompleted(id);
    await queue.clearCompleted();
    final ops = await db.select(db.syncOperations).get();
    expect(ops, hasLength(1));
    expect(ops.first.type, 'a');
  });

  test('enqueueLatest keeps only the newest pending payload', () async {
    await queue.enqueueLatest(type: 'music.progress:item-1', payload: 'old');
    await queue.enqueueLatest(type: 'music.progress:item-1', payload: 'new');

    final operations = await queue.dequeue();

    expect(operations, hasLength(1));
    expect(operations.single.payload, 'new');
  });

  test('generic dequeue leaves reader operations to ReaderSyncQueue', () async {
    await queue.enqueue(type: 'reader.progress', payload: '{}');
    await queue.enqueue(type: 'music.play_history', payload: '{}');

    final operations = await queue.dequeue();

    expect(operations.map((operation) => operation.type), [
      'music.play_history',
    ]);
  });
}
