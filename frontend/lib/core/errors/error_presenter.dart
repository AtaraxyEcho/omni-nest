import 'package:flutter/material.dart';
import 'package:omninest/core/errors/app_exception.dart';

void showAppError(BuildContext context, AppException error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.message)));
}
