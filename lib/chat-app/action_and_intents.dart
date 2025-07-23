
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/log_page.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';

class GotoLogPageIntent extends Intent {
  const GotoLogPageIntent();
}

class GotoLogPageAction extends Action<GotoLogPageIntent> {
  final BuildContext context;
  GotoLogPageAction(this.context);

  @override
  void invoke(GotoLogPageIntent intent) { 
    customNavigate(LogPage(), context: context);
  }
}