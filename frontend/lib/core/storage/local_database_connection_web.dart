import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// 打开 Web 平台 SQLite 数据库连接。
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'omninest_cache',
        sqlite3Uri: Uri.parse('/sqlite3.wasm'),
        driftWorkerUri: Uri.parse('/drift_worker.js'),
      );
      return result.resolvedExecutor;
    }),
  );
}
