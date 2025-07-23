import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/new_group_chat.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import '../../providers/chat_controller.dart';
import '../../widgets/chat/chat_list_item.dart';

class ChatPage extends StatefulWidget {
  final void Function(ChatModel chat)? onSelectChat;

  const ChatPage({Key? key, this.onSelectChat}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatController chatController = Get.find<ChatController>();
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchText = ''.obs;

  bool isQuerying = false;
  bool _isSortingMode = false; // 新增状态：是否处于排序模式

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchText.value = _searchController.text;
      setState(() {
        if (_searchText.value.isEmpty) {
          isQuerying = false;
        } else {
          isQuerying = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 正常模式下的列表
  Widget _buildNormalList(ThemeData theme) {
    return Obx(() {
      final filteredChats = chatController.chats
          .where((chat) =>
              chat.name.toLowerCase().contains(_searchText.value.toLowerCase()))
          .toList();
      return ListView.separated(
        itemCount: filteredChats.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) => ChatListItem(
          chatId: filteredChats.reversed.toList()[index].id,
          onSelectChat: widget.onSelectChat,
        ),
      );
    });
  }

  // 排序模式下的列表
  Widget _buildReorderableList(ThemeData theme) {
    // 中文注释: ReorderableListView.builder 是 Flutter 的一个内置组件, 它能够创建一个可重新排序的列表。用户可以通过长按并拖动列表项来改变它们的顺序。
    return ReorderableListView.builder(
      itemCount: chatController.chats.length,
      itemBuilder: (context, index) {
        // 中文注释: 为了保证视图一致性, 排序时也从倒序列表获取数据项。
        final chat = chatController.chats.reversed.toList()[index];
        // 中文注释: 为了让 ReorderableListView 能够正确识别和移动项目, 每个列表项都必须有一个唯一的 Key。
        // 同时, 在排序模式下, 禁用原有的点击事件, 并通过在外部包裹一层 ListTile 来添加一个拖拽图标。
        return Material(
          key: ValueKey(chat.id),
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: ChatListItem(
              chatId: chat.id,
              onSelectChat: (p0) {
                // 排序模式下禁用选择
              },
            ),
            trailing: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.drag_handle),
            ),
            onTap: null, // 禁用点击
          ),
        );
      },
      onReorder: (int oldIndex, int newIndex) {
        // 当用户拖拽结束后, 此回调函数会被调用
        setState(() {
          // 1. 获取当前UI上显示的倒序列表的副本
          final reversedList = chatController.chats.reversed.toList();

          // 2. ReorderableListView 的标准操作：如果向下拖动，newIndex需要减1
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }

          // 3. 在倒序列表的副本上执行移动操作
          final movedChat = reversedList.removeAt(oldIndex);
          reversedList.insert(newIndex, movedChat);

          // 4. 将排序完成的倒序列表再次反转，得到正确的底层存储顺序
          // 5. 中文注释: 使用 assignAll 方法来原子性地更新整个列表, 以确保 GetX 能够正确地响应状态变化。
          chatController.chats.assignAll(reversedList.reversed);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [

          // 在非排序模式下显示搜索框和新建按钮
          if (!_isSortingMode)
            Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索聊天',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    cursorColor: theme.colorScheme.primary,
                  ),
                ),
                Obx(() => AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _searchText.isEmpty
                          ? Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 8.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      if (widget.onSelectChat != null) {
                                        widget.onSelectChat!(
                                            chatController.defaultChat.value);
                                      } else {
                                        customNavigate(
                                            ChatDetailPage(chatId: -1),
                                            context: context);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                          const SizedBox(width: 12),
                                          Text(
                                            '创建新聊天',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 8.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      customNavigate(NewChatPage(),
                                          context: context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.group,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                          const SizedBox(width: 12),
                                          Text(
                                            '创建新群聊',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    )),
              ],
            ),
          Expanded(
              child: // Obx(() {
                  // Obx 用于监听 chatController.chats 的变化, 使得排序后能实时刷新UI
                  (_isSortingMode)
                      ? _buildReorderableList(theme)
                      : _buildNormalList(theme)

              //}),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _isSortingMode ? '完成排序' : '进入排序',
        onPressed: () {
          setState(() {
            _isSortingMode = !_isSortingMode;
          });
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            _isSortingMode ? Icons.check : Icons.sort,
            key: ValueKey<bool>(_isSortingMode),
          ),
        ),
      ),
    );
  }
}
