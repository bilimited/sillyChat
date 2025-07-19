import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';

class PromptPreviewPage extends StatefulWidget {

  final List<Map<String, String>> messages;
  
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
        actions: [
          Row(
            children: [
              Text('分组模式'),
              Switch(
                value: isGroupMode,
                onChanged: (value) {
                  setState(() {
                    isGroupMode = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: isGroupMode
          ? _buildGroupedList()
          : ListView.builder(
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
                            message['role'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getRoleColor(message['role']),
                            ),
                          ),
                          subtitle: Text(
                            message['content'] ?? '',
                          ),
                        ),
                        Text(
                          "长度: ${(message['content'] ?? '').length}",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      ],
                    ));
              },
            ),
    );
  }

  Widget _buildGroupedList() {
    // 按role分组
    Map<String, List<Map<String, String>>> groupedMessages = {};
    for (var message in widget.messages) {
      String role = message['role'] ?? '';
      if (!groupedMessages.containsKey(role)) {
        groupedMessages[role] = [];
      }
      groupedMessages[role]!.add(message);
    }

    return ListView.builder(
      itemCount: groupedMessages.length,
      itemBuilder: (context, index) {
        String role = groupedMessages.keys.elementAt(index);
        var messages = groupedMessages[role]!;
        
        return ExpansionTile(
          title: Text(
            '$role (${messages.length})',
            style: TextStyle(
              color: _getRoleColor(role),
              fontWeight: FontWeight.bold,
            ),
          ),
          children: messages.map((message) => ListTile(
            title: Text(message['content'] ?? ''),
            trailing: Text(
              "长度: ${(message['content'] ?? '').length}",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )).toList(),
        );
      },
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
