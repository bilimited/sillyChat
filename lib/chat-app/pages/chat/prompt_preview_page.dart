import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';

class PromptPreviewPage extends StatefulWidget {
  final List<LLMMessage> messages;

  const PromptPreviewPage({Key? key, required this.messages}) : super(key: key);

  @override
  State<PromptPreviewPage> createState() => _PromptPreviewPageState();
}

class _PromptPreviewPageState extends State<PromptPreviewPage> {
  bool isGroupMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prompt预览'),
      ),
      body: ListView.builder(
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      message.role,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(message.role),
                      ),
                    ),
                    subtitle: Text(
                      message.content,
                    ),
                  ),
                  Text(
                    "长度: ${(message.content).length}",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                ],
              ));
        },
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'system':
        return Colors.purple;
      case 'assistant':
        return Colors.blue;
      case 'user':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
