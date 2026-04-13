import 'package:flutter/material.dart';

Future<void> kembaliAtauKe(BuildContext context, Widget fallbackPage) async {
  final navigator = Navigator.of(context);

  if (navigator.canPop()) {
    navigator.pop();
    return;
  }

  navigator.pushReplacement(MaterialPageRoute(builder: (_) => fallbackPage));
}
