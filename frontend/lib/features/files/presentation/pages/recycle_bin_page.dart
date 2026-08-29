import 'package:flutter/material.dart';
import 'package:omninest/features/files/application/file_browser_controller.dart';
import 'package:omninest/features/files/presentation/pages/file_browser_page.dart';

class RecycleBinPage extends StatelessWidget {
  const RecycleBinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FileBrowserPage(initialSection: FileManagerSection.recycleBin);
  }
}
