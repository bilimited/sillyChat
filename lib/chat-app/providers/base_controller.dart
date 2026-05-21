import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
abstract class BaseController extends GetxController {
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;
  @override
  void onInit() {
    super.onInit();
  }

  @protected
  void markReady() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }
}