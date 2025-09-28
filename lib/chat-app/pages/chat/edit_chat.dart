import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/prompt_preview_page.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:flutter_example/chat-app/widgets/chat/member_selector.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/kv_editor.dart';
import 'package:flutter_example/chat-app/widgets/lorebook/lorebook_activator.dart';
import 'package:get/get.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_controller.dart';
import '../../providers/character_controller.dart';

import 'package:path/path.dart' as p;

class EditChatPage extends StatefulWidget {
  final ChatSessionController session;

  ChatModel get chat => session.chat;

  const EditChatPage({Key? key, required this.session}) : super(key: key);

  @override
  _EditChatPageState createState() => _EditChatPageState();
}

class _EditChatPageState extends State<EditChatPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final ChatController _chatController = Get.find();
  final CharacterController _characterController = Get.find();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          _saveChanges(isBack: false);
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text('编辑聊天'),
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: '聊天信息'),
                  Tab(text: '成员管理'),
                  Tab(text: '变量设置'),
                ],
              ),
              actions: [],
            ),
            // floatingActionButton: FloatingActionButton.extended(
            //   onPressed: _saveChanges,
            //   label: Text('保存修改'),
            //   icon: Icon(Icons.save),
            // ),
            body: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    {
                      Get.back();
                    }
                  }
                },
                child: Column(
                  children: [
                    // 群聊ID显示
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(8),
                      color: colors.surfaceContainerHighest,
                      child: Text(
                        widget.chat.id == -1
                            ? '聊天未创建'
                            : '聊天ID：${widget.chat.id}; 文件名:${p.basename(widget.chat.file.path)}',
                        style: TextStyle(
                          color: widget.chat.id == -1
                              ? colors.outline
                              : colors.outline,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBasicInfoTab(),
                          _buildMembersTab(),
                          _buildAdvanceTab()
                        ],
                      ),
                    ),
                  ],
                ))));
  }

  // 基本信息标签页
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: widget.chat.name,
                        onChanged: (value) {
                          widget.chat.name = value;
                        },
                        decoration: InputDecoration(
                          labelText: '聊天标题（可选）',
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        initialValue: widget.chat.description,
                        onChanged: (value) {
                          widget.chat.description = value;
                        },
                        decoration: InputDecoration(
                          labelText: '作者注释（可选）',
                        ),
                        maxLines: null,
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                              child: DropdownButtonFormField<int>(
                            value: Get.find<ChatOptionController>()
                                    .chatOptions
                                    .any((option) =>
                                        option.id == widget.chat.chatOptionId)
                                ? widget.chat.chatOptionId
                                : null,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            hint: const Text('选择聊天预设'),
                            items: Get.find<ChatOptionController>()
                                .chatOptions
                                .map((option) {
                              return DropdownMenuItem<int>(
                                value: option.id,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 250),
                                  child: Text(
                                    '${option.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (int? value) {
                              if (value != null) {
                                widget.chat.chatOptionId = value;
                                if (widget.chat.isChatNotCreated) return;
                                _saveChanges(isBack: false);
                              }
                            },
                          )),
                          IconButton(
                              onPressed: () {
                                customNavigate(
                                    EditChatOptionPage(
                                      option: widget.chat.chatOption,
                                    ),
                                    context: context);
                              },
                              icon: Icon(Icons.edit)),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildRoleSelector(
                          label: '你扮演：',
                          roleId: widget.chat.userId,
                          onSelect: (id) =>
                              setState(() => widget.chat.userId = id),
                          placeholder: '留空以使用全局自设'),
                      SizedBox(height: 8),
                      _buildRoleSelector(
                        label: 'AI扮演：',
                        roleId: widget.chat.assistantId,
                        onSelect: (id) =>
                            setState(() => widget.chat.assistantId = id),
                      ),
                    ],
                  )),
            ),
            SizedBox(height: 16),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text('查看Prompt'),
                    leading: Icon(Icons.preview),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      final messages = Promptbuilder(
                              widget.chat, widget.chat.assistant.bindOption)
                          .getLLMMessageList();
                      customNavigate(PromptPreviewPage(messages: messages),
                          context: context);
                    },
                  ),
                  ListTile(
                    title: Text('查看详细信息'),
                    leading: Icon(Icons.info),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      customNavigate(ChatDetailPage(chatModel: widget.chat),
                          context: context);
                    },
                  ),
                  // 一个视觉上的分隔
                  const Divider(height: 1),
                  const SizedBox(height: 8), // 增加一些垂直间距
                  TextButton.icon(
                    icon: Icon(Icons.book),
                    label: Text('临时开/关世界书条目'),
                    onPressed: () {
                      final global = Get.find<LoreBookController>()
                          .globalActivitedLoreBooks;
                      final chars = widget.chat.characters
                          .expand((char) => char.loreBooks)
                          .toList();

                      customNavigate(
                          LoreBookActivator(
                            chatSessionController: widget.session,
                            lorebooks: [
                              ...{...global, ...chars}
                            ],
                            chat: widget.chat,
                          ),
                          context: context);
                    },
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.delete_sweep),
                    label: Text('清空聊天记录'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Colors.orange, // foregroundColor 控制图标和文字颜色
                    ),
                    onPressed: _clearMessages,
                  ),
                  const SizedBox(height: 16), // 底部留白
                ],
              ),
            ),
            const SizedBox(
              height: 64,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector(
      {required String label,
      required int? roleId,
      required Function(int?) onSelect,
      String? placeholder}) {
    final character =
        roleId != null ? _characterController.getCharacterById(roleId) : null;

    return Row(
      children: [
        Text(label),
        Expanded(
          child: InkWell(
            onTap: () async {
              CharacterModel? char =
                  await customNavigate(CharacterSelector(), context: context);
              if (char == null) {
                return;
              }
              onSelect(char.id);
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceBright,
                borderRadius: BorderRadius.circular(10),
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
                        Text(placeholder ?? '选择角色'),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsEditor() {
    return Column(
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            ...widget.chat.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () {
                        setState(() {
                          widget.chat.tags.remove(tag);
                        });
                      },
                    ))
                .toList(),
            ActionChip(
              avatar: Icon(Icons.add, size: 18),
              label: Text('添加标签'),
              onPressed: () {
                final TextEditingController tagController =
                    TextEditingController();
                Get.dialog(
                  AlertDialog(
                    title: Text('添加标签'),
                    content: TextField(
                      controller: tagController,
                      decoration: InputDecoration(
                        hintText: '输入标签名称',
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (tagController.text.isNotEmpty) {
                            setState(() {
                              widget.chat.tags.add(tagController.text);
                            });
                            Get.back();
                          }
                        },
                        child: Text('确定'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // 成员管理标签页
  Widget _buildMembersTab() {
    return MemberSelector(
      selectedMembers: widget.chat.characterIds,
      onToggleMember: _toggleMember,
    );
  }

  Widget _buildAdvanceTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: KeyValueEditor(
          initialMap: widget.chat.chatVars,
          onChanged: (newMap) {
            setState(() {
              widget.chat.chatVars = newMap;
            });
          }),
    );
  }

  // 高级设置标签页

  void _saveChanges({bool isBack = true}) async {
    if (widget.chat.id == -1 && isBack) {
      Get.back();
      return;
    }
    if (_formKey.currentState?.validate() ?? true) {
      //await  //_chatController.refleshAll();
      await widget.session.saveChat();
      widget.session.reflesh();
      if (isBack) {
        Get.back();
      }
    } else {}
  }

  void _toggleMember(int characterId) {
    setState(() {
      if (widget.chat.characterIds.contains(characterId)) {
        widget.chat.characterIds.remove(characterId);
      } else {
        widget.chat.characterIds.add(characterId);
      }
    });
    // _saveChanges();
  }

  void _clearMessages() {
    Get.dialog(
      AlertDialog(
        title: Text('确认清空'),
        content: Text('确定要清空所有聊天记录吗？该操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              widget.chat.messages.clear();
              widget.chat.lastMessage = '无消息';
              await widget.session.saveChat();
              _chatController.chats.refresh();
              Get.back();
              Get.back();
              Get.snackbar('成功', '聊天记录已清空');
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}
