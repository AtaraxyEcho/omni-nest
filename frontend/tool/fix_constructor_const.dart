// Dart 脚本：恢复被误删的构造器 const
// 用法: dart run tool/fix_constructor_const.dart

import 'dart:convert';
import 'dart:io';

void main() {
  final base = Directory('lib/features');

  final files =
      base
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

  for (final file in files) {
    var content = file.readAsStringSync();
    var original = content;

    // 种草：恢复被误删的构造器 const
    // 匹配 "ClassName({" 前面没有 const 的情况
    // 但只在类定义内部（缩进 >= 2 空格）
    final lines = content.split('\n');
    final newLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // 检查是否是构造器定义（缩进 + ClassName({）
      if (RegExp(r'^\s{2,}(\w+)\(\{').hasMatch(line)) {
        // 检查是否已经有 const
        if (!line.contains(RegExp(r'\bconst\s'))) {
          // 检查是否是 StatelessWidget/StatefulWidget/ConsumerWidget 等的构造器
          // 向上找 class 声明
          var isWidgetConstructor = false;
          for (var j = i - 1; j >= 0; j--) {
            if (lines[j].contains(RegExp(r'class\s+\w+\s+extends\s+'))) {
              if (lines[j].contains('StatelessWidget') ||
                  lines[j].contains('StatefulWidget') ||
                  lines[j].contains('ConsumerWidget') ||
                  lines[j].contains('ConsumerStatefulWidget') ||
                  lines[j].contains('StatelessComponent') ||
                  lines[j].contains('StatefulComponent')) {
                isWidgetConstructor = true;
              }
              break;
            }
          }

          if (isWidgetConstructor) {
            // 添加 const
            line = line.replaceFirst(RegExp(r'^(\s+)'), '\$1const ');
          }
        }
      }
      newLines.add(line);
    }

    content = newLines.join('\n');

    if (content != original) {
      file.writeAsStringSync(content, encoding: utf8);
    }
  }
}
