import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/member_selector.dart';
import 'package:get/get.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_controller.dart';
import '../../providers/character_controller.dart';

class NewChatPage extends StatefulWidget {
  @override
  _NewChatPageState createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedUserId = 0;
  int? _selectedAssistantId;
  final List<int> _selectedIds = [];
  ChatMode? _selectedMode = ChatMode.group; // 添加模式选择变量
  ChatOptionModel? _selectedOption;

  final CharacterController _characterController = Get.find();
  final ChatController _chatController = Get.find();
  final ChatOptionController _chatOptionController = Get.find();

  @override
  void initState() {
    super.initState();
    if (_chatOptionController.chatOptions.isNotEmpty)
      _selectedOption = _chatOptionController.chatOptions[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('创建新群聊'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(10.0),
          children: [
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '群聊标题（可选）',
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Obx(() => DropdownButtonFormField<ChatOptionModel>(
                          value: _selectedOption,
                          decoration: InputDecoration(
                            labelText: '对话预设',
                          ),
                          items:
                              _chatOptionController.chatOptions.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Text(option.name),
                            );
                          }).toList(),
                          onChanged: (ChatOptionModel? newValue) {
                            setState(() {
                              _selectedOption = newValue;
                            });
                          },
                        )),
                  )
                ],
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Card(
              child: Padding(
                  padding: EdgeInsets.all(10),
                  child: _selectedMode == ChatMode.group
                      ? SizedBox(
                          height: 400,
                          child: MemberSelector(
                            selectedMembers: _selectedIds,
                            onToggleMember: (characterId) {
                              setState(() {
                                if (_selectedIds.contains(characterId)) {
                                  _selectedIds.remove(characterId);
                                } else {
                                  _selectedIds.add(characterId);
                                }
                              });
                            },
                          ),
                        )
                      : Column(
                          children: [
                            _buildRoleSelector(
                              label: '你扮演：',
                              roleId: _selectedUserId,
                              onSelect: (id) =>
                                  setState(() => _selectedUserId = id),
                            ),
                            SizedBox(height: 8),
                            _buildRoleSelector(
                              label: 'AI扮演：',
                              roleId: _selectedAssistantId,
                              onSelect: (id) =>
                                  setState(() => _selectedAssistantId = id),
                            ),
                          ],
                        )),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createChat,
        label: Text('创建对话'),
        icon: Icon(Icons.add_comment),
      ),
    );
  }

  Widget _buildRoleSelector({
    required String label,
    required int? roleId,
    required Function(int?) onSelect,
  }) {
    final character =
        roleId != null ? _characterController.getCharacterById(roleId) : null;

    return Row(
      children: [
        Text(label),
        Expanded(
          child: InkWell(
            onTap: () async {
              CharacterModel? char = await Get.to(() => CharacterSelector());
              if (char == null) {
                return;
              }
              onSelect(char.id);
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: character != null
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: FileImage(File(character.avatar)),
                        ),
                        SizedBox(width: 8),
                        Text(character.roleName),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, size: 16),
                          onPressed: () => onSelect(null),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_outlined),
                        SizedBox(width: 8),
                        Text('选择角色'),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _createChat() async {
    if (_selectedMode == ChatMode.auto &&
        (_selectedUserId == null || _selectedAssistantId == null)) {
      Get.snackbar('错误', '请选择用户和AI角色');
      return;
    } else if (_selectedMode == ChatMode.group) {
      if (_selectedIds.length < 2) {
        Get.snackbar('错误', '至少选择2个角色');
        return;
      }
      _selectedUserId = 0;

      _selectedAssistantId = _selectedIds.where((id) => id != 0).toList()[0];
    }

    final assistant =
        _characterController.getCharacterById(_selectedAssistantId!);
    final user = _characterController.getCharacterById(_selectedUserId!);

    // List<int> promptIds = [];
    // if (!assistant.promptIds.isEmpty) {
    //   promptIds = assistant.promptIds;
    // }

    final defaultName = _selectedMode == ChatMode.group
        ? "新群聊"
        : user.id == 0
            ? assistant.roleName
            : "${user.roleName}和${assistant.roleName}的聊天";

    final newChat = ChatModel(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _nameController.text.isEmpty ? defaultName : _nameController.text,
      avatar:
          _characterController.getCharacterById(_selectedAssistantId!).avatar,
      lastMessage: '对话已创建',
      time: DateTime.now().toString(),
      messages: [],
      userId: null,
      assistantId: _selectedAssistantId,
    )
      ..mode = _selectedMode
      ..characterIds = _selectedIds; // 设置选择的模式
    if (_selectedOption != null) {
      newChat.initOptions(_selectedOption!);
    }

    // TODO:更改新建聊天逻辑，在这里获取聊天路径
    await _chatController.createChat(
        newChat, await SettingController.of.getChatPath());
    Get.back();
    Get.snackbar('成功', '对话创建成功');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
