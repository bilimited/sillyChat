import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';

class MoreFirstMessagePage extends StatefulWidget {
  final CharacterModel character;

  const MoreFirstMessagePage({Key? key, required this.character})
      : super(key: key);

  @override
  _MoreFirstMessagePageState createState() => _MoreFirstMessagePageState();
}

class _MoreFirstMessagePageState extends State<MoreFirstMessagePage> {
  late List<String> messages;

  @override
  void initState() {
    super.initState();
    messages = List<String>.from(widget.character.moreFirstMessage);
  }

  void _addMessage() {
    setState(() {
      messages.add('');
    });
  }

  void _updateMessage(int index, String value) {
    setState(() {
      messages[index] = value;
    });
  }

  void _deleteMessage(int index) {
    setState(() {
      messages.removeAt(index);
    });
  }

  void _saveChanges() {
    widget.character.moreFirstMessage = List<String>.from(messages);
    //Get.back(); // 返回上一页
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _saveChanges();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('更多开场白'),
        ),
        body: ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                title: TextFormField(
                  initialValue: messages[index],
                  decoration: InputDecoration(
                    labelText: '消息 ${index + 1}',
                    labelStyle: TextStyle(color: theme.primaryColor),
                  ),
                  onChanged: (value) => _updateMessage(index, value),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: theme.colorScheme.error),
                  onPressed: () => _deleteMessage(index),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addMessage,
          child: const Icon(Icons.add),
          backgroundColor: theme.primaryColor,
        ),
      ),
    );
  }
}
