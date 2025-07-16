import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/chat/prompt_preview_page.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:flutter_example/chat-app/widgets/chat/member_selector.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/prompt/prompt_editor.dart';
import 'package:get/get.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_controller.dart';
import '../../providers/character_controller.dart';
import '../../widgets/prompt/request_options_editor.dart';

class EditChatPage extends StatefulWidget {
  final ChatModel chat;

  const EditChatPage({Key? key, required this.chat}) : super(key: key);

  @override
  _EditChatPageState createState() => _EditChatPageState();
}

class _EditChatPageState extends State<EditChatPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late ChatModel chat;
  final _formKey = GlobalKey<FormState>();
  final ChatController _chatController = Get.find();
  final CharacterController _characterController = Get.find();
  final ChatOptionController _chatOptionController = Get.find();

  // 傻逼Flutter。强制刷新
  Key _advanceTabKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    _tabController = TabController(length: 3, vsync: this);
  }

  void _onOptionsDirty() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
        appBar: AppBar(
          title: Text('编辑聊天'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: '聊天信息'),
              Tab(text: '聊天设置'),
              Tab(text: '成员管理'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.content_copy),
              onPressed: () async {
                final newChat = _chatController.cloneChat(widget.chat);
                newChat.name = '${widget.chat.name} - 副本';
                await _chatController.addChat(newChat);
                Get.back();
                Get.back();

                Get.snackbar('成功', '群聊已复制');
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveChanges,
          label: Text('保存修改'),
          icon: Icon(Icons.save),
        ),
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
                        : '聊天ID：${widget.chat.id}; File ID:${widget.chat.fileId}',
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
                      _buildAdvancedTab(),
                      _buildMembersTab(),
                    ],
                  ),
                ),
              ],
            )));
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
                      final messages =
                          Promptbuilder().getLLMMessageList(widget.chat);
                      customNavigate(
                          PromptPreviewPage(
                              messages: messages
                                  .map((ele) => ele.toOpenAIJson())
                                  .toList()),
                          context: context);
                    },
                  ),
                  // 一个视觉上的分隔
                  const Divider(height: 1),
                  const SizedBox(height: 8), // 增加一些垂直间距

                  // 使用 TextButton 或 OutlinedButton 强调危险操作
                  TextButton.icon(
                    icon: Icon(Icons.delete_sweep),
                    label: Text('清空聊天记录'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Colors.orange, // foregroundColor 控制图标和文字颜色
                    ),
                    onPressed: _clearMessages,
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.delete_forever),
                    label: Text('删除群聊'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: _deleteChat,
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

  // 高级设置标签页
  Widget _buildAdvancedTab() {
    return ListView(
      key: _advanceTabKey,
      padding: EdgeInsets.all(10),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                TextFormField(
                  initialValue: chat.chatOption.name,
                  onChanged: (value) {
                    chat.chatOption.name = value;
                  },
                  decoration: InputDecoration(
                    labelText: '预设名称',
                  ),
                ),
                SizedBox(
                  height: 16,
                ),
                Flex(
                  direction: Axis.horizontal,
                  children: [
                    Flexible(
                      child: IconButton(
                        icon: Icon(Icons.refresh),
                        tooltip: '替换',
                        onPressed: () async {
                          Get.dialog(
                            AlertDialog(
                              title: const Text('切换对话预设'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount:
                                      _chatOptionController.chatOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = _chatOptionController
                                        .chatOptions[index];
                                    return ListTile(
                                      title: Text(option.name),
                                      onTap: () {
                                        setState(() {
                                          chat.initOptions(option);
                                          Get.back();
                                        });
                                        _advanceTabKey = UniqueKey();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (chat.chatOption.id != 0) ...[
                      SizedBox(width: 12),
                      Flexible(
                        child: IconButton(
                          icon: Icon(Icons.restart_alt),
                          tooltip: '重置',
                          onPressed: () async {
                            await Get.dialog(
                              AlertDialog(
                                title: Text('重置预设'),
                                content: Text('确定要重置该预设为默认值吗？此操作不可恢复。'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(result: false),
                                    child: Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final option = _chatOptionController
                                          .getChatOptionById(
                                              chat.chatOption.id);
                                      if (option != null) {
                                        setState(() {
                                          chat.initOptions(option);
                                          Get.back();
                                        });
                                      }
                                    },
                                    child: Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: IconButton(
                          icon: Icon(Icons.save),
                          tooltip: '更新',
                          onPressed: () async {
                            await Get.dialog(
                              AlertDialog(
                                title: Text('更新预设'),
                                content: Text('确定要用当前聊天配置更新聊天预设吗？此操作不可恢复。'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(result: false),
                                    child: Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final option = _chatOptionController
                                          .getChatOptionById(
                                              chat.chatOption.id);
                                      if (option != null) {
                                        setState(() {
                                          _chatOptionController
                                              .updateChatOption(
                                                  chat.chatOption
                                                      .copyWith(true),
                                                  null);
                                          Get.back();
                                        });
                                        _advanceTabKey = UniqueKey();
                                      }
                                    },
                                    child: Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: IconButton(
                          icon: Icon(Icons.save_as),
                          tooltip: '另存为',
                          onPressed: () async {
                            await Get.dialog(
                              AlertDialog(
                                title: Text('另存为预设'),
                                content: Text('确定要将该预设保存为新预设吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(result: false),
                                    child: Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _chatOptionController.addChatOption(
                                          chat.chatOption.copyWith(true,
                                              id: DateTime.now()
                                                  .microsecondsSinceEpoch),
                                        );
                                        Get.back();
                                      });
                                    },
                                    child: Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  clipBehavior: Clip.hardEdge,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        Card(
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('提示词设置', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 10),
                PromptEditor(
                  prompts: chat.prompts,
                  onPromptsChanged: (newPrompts) {
                    setState(() => chat.prompts = newPrompts);
                    _onOptionsDirty();
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('对话参数设置', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 16),
                RequestOptionsEditor(
                  options: chat.requestOptions,
                  onChanged: (newOptions) {
                    setState(() {
                      chat.requestOptions = newOptions;
                    });
                    _onOptionsDirty();
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 64,
        )
      ],
    );
  }

  void _saveChanges({bool isBack = true}) async {
    if (widget.chat.id == -1 && isBack) {
      Get.back();
      return;
    }
    if (_formKey.currentState?.validate() ?? true) {
      await _chatController.refleshAll();
      await _chatController.saveChats(widget.chat.fileId);
      if (isBack) {
        Get.back();
      }

      // Get.snackbar('成功', '群聊信息已更新');
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
              //await _chatController.updateChat(widget.chat.id, widget.chat);
              await _chatController.saveChats(widget.chat.fileId);
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

  void _deleteChat() {
    if (widget.chat.id == -1) {
      return;
    }
    Get.dialog(
      AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除该群聊吗？该操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _chatController.deleteChat(widget.chat.id);
              Get.back(); // 返回到Edit_Chat
              Get.back(); // 返回到聊天界面
              Get.back(); // 返回到主界面
              Get.snackbar('成功', '群聊已删除');
            },
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
