import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:get/get.dart';

class EditMessagePage extends StatefulWidget {
  final int chatId;
  final MessageModel message;

  const EditMessagePage({
    Key? key,
    required this.chatId,
    required this.message,
  }) : super(key: key);

  @override
  State<EditMessagePage> createState() => _EditMessagePageState();
}

class _EditMessagePageState extends State<EditMessagePage> {
  late TextEditingController _editController;
  final ChatController _chatController = Get.find<ChatController>();
  late int _senderId;
  late MessageType _messageType;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.content);
    _senderId = widget.message.sender;
    _messageType = widget.message.type;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characterController = Get.find<CharacterController>();
    final sender = characterController.getCharacterById(_senderId);

    return Scaffold(
      appBar: AppBar(title: const Text('编辑消息')),
      body: Column(
        children: [
          // 发送者选择
          ListTile(
            leading: sender.avatar.isNotEmpty
                ? CircleAvatar(
                    backgroundImage: FileImage(File(sender.avatar)),
                  )
                : const CircleAvatar(child: Icon(Icons.person)),
            title: Text(sender.roleName),
            subtitle: Text('点击选择发送者'),
            onTap: () async {
              final selected = await Get.to<CharacterModel?>(
                () => CharacterSelector(),
              );
              if (selected != null) {
                setState(() {
                  _senderId = selected.id;
                });
              }
            },
          ),
          // 消息类型选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<MessageType>(
              value: _messageType,
              decoration: const InputDecoration(
                labelText: '消息类型',
              ),
              items: [
                DropdownMenuItem(
                  value: MessageType.text,
                  child: Text('文本'),
                ),
                DropdownMenuItem(
                  value: MessageType.narration,
                  child: Text('旁白'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _messageType = val;
                  });
                }
              },
            ),
          ),
          // 消息内容编辑
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + 64),
              child: TextField(
                textAlignVertical: TextAlignVertical.top,
                controller: _editController,
                decoration: const InputDecoration(
                  hintText: '输入新的消息内容',
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _save,
            label: const Text('保存'),
            icon: const Icon(Icons.save),
            heroTag: 'saveBtn',
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _appendSave,
            label: const Text('追加保存'),
            icon: const Icon(Icons.add),
            heroTag: 'appendSaveBtn',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _save() {
    if (_editController.text.isNotEmpty) {
      setState(() {
        widget.message.content = _editController.text;
        widget.message.sender = _senderId;
        widget.message.type = _messageType;
      });
      _chatController.updateMessage(
          widget.chatId, widget.message.time, widget.message);
      Get.back();
    }
  }

  void _appendSave() {
    if (_editController.text.isNotEmpty) {
      int firstNull = widget.message.alternativeContent.indexOf(null); // 这个不会为空，否则一定是出了bug
      if (firstNull != -1) {
        widget.message.alternativeContent[firstNull] = widget.message.content;
      } else {
        Get.snackbar('title', '这个不会为空，否则一定是出了bug');
        widget.message.alternativeContent.add(widget.message.content);
      }
      widget.message.alternativeContent.add(null);
      setState(() {
        widget.message.content = _editController.text;
        widget.message.sender = _senderId;
        widget.message.type = _messageType;
      });
      _chatController.updateMessage(
          widget.chatId, widget.message.time, widget.message);
      Get.back();
    }
  }
}
