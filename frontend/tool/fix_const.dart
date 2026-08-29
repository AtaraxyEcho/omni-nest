// Dart 脚本：精准修复 const 构造器调用中的 context.xxxColors 问题
// 只处理构造器调用（const Widget(），不处理构造器定义（Widget({）
// 用法: dart run tool/fix_const.dart

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

    // 种草：移除构造器调用中的 const（不处理构造器定义）
    final lines = content.split('\n');
    final newLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // 检查这行是否有 const
      if (line.contains(RegExp(r'\bconst\s'))) {
        // 排除构造器定义：行尾有 "{"
        if (line.trimRight().endsWith('{')) {
          newLines.add(line);
          continue;
        }

        // 检查后续 15 行内是否有 context.xxxColors
        var hasThemeColor = false;
        for (var j = i; j < i + 15 && j < lines.length; j++) {
          if (lines[j].contains(
            RegExp(
              r'context\.(musicColors|videoColors|readerColors|photosColors)',
            ),
          )) {
            hasThemeColor = true;
            break;
          }
          // 遇到闭合括号停止
          if (RegExp(r'^\s*\);').hasMatch(lines[j])) break;
        }

        if (hasThemeColor) {
          // 移除 const
          line = line.replaceFirst(RegExp(r'\bconst\s'), '');
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
