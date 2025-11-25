import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:get/get.dart';

class EditMessagePage extends StatefulWidget {
  final ChatSessionController sessionController;
  final MessageModel message;

  const EditMessagePage({
    Key? key,
    required this.sessionController,
    required this.message,
  }) : super(key: key);

  @override
  State<EditMessagePage> createState() => _EditMessagePageState();
}

class _EditMessagePageState extends State<EditMessagePage> {
  late TextEditingController _editController;
  late int _senderId;
  late MessageStyle _messageType;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.content);
    _senderId = widget.message.senderId;
    _messageType = widget.message.style;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  // 打开角色选择器
  Future<void> _changeSender() async {
    final selected = await Get.to<CharacterModel?>(
      () => CharacterSelector(),
    );
    if (selected != null) {
      setState(() {
        _senderId = selected.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final characterController = Get.find<CharacterController>();
    final sender = characterController.getCharacterById(_senderId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑消息'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. 顶部工具栏：紧凑布局 (发送者 + 消息类型)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // 左侧：发送者选择 (点击整个区域触发)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _changeSender,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        sender.avatar.isNotEmpty
                            ? CircleAvatar(
                                radius: 16,
                                backgroundImage: FileImage(File(sender.avatar)),
                              )
                            : const CircleAvatar(
                                radius: 16,
                                child: Icon(Icons.person, size: 16)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '发送者',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  sender.roleName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // 右侧：消息类型选择
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MessageStyle>(
                      value: _messageType,
                      isDense: true,
                      icon: const Icon(Icons.tune, size: 18),
                      style: theme.textTheme.bodyMedium,
                      items: const [
                        DropdownMenuItem(
                          value: MessageStyle.common,
                          child: Text('文本'),
                        ),
                        DropdownMenuItem(
                          value: MessageStyle.narration,
                          child: Text('旁白'),
                        ),
                        DropdownMenuItem(
                          value: MessageStyle.summary,
                          child: Text('摘要'),
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
                ),
              ],
            ),
          ),

          // 2. 消息内容编辑 (占据剩余空间)
          Expanded(
            child: TextField(
              controller: _editController,
              textAlignVertical: TextAlignVertical.top,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 16, height: 1.5),
              decoration: const InputDecoration(
                hintText: '在此输入消息内容...',
                border: InputBorder.none, // 去掉边框，像记事本一样
                contentPadding:
                    EdgeInsets.fromLTRB(16, 16, 16, 100), // 底部留出 100px 给按钮
              ),
            ),
          ),
        ],
      ),

      // 3. 悬浮按钮
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
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_editController.text.isNotEmpty) {
      setState(() {
        widget.message.content = _editController.text;
        widget.message.senderId = _senderId;
        widget.message.style = _messageType;
      });
      widget.sessionController
          .updateMessage(widget.message.time, widget.message);
      Get.back();
    }
  }

  void _appendSave() {
    if (_editController.text.isNotEmpty) {
      int firstNull = widget.message.alternativeContent.indexOf(null);
      if (firstNull != -1) {
        widget.message.alternativeContent[firstNull] = widget.message.content;
      } else {
        widget.message.alternativeContent.add(widget.message.content);
      }
      widget.message.alternativeContent.add(null);
      setState(() {
        widget.message.content = _editController.text;
        widget.message.senderId = _senderId;
        widget.message.style = _messageType;
      });
      widget.sessionController
          .updateMessage(widget.message.time, widget.message);
      Get.back();
    }
  }
}
