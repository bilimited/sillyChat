import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
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
  bool _isSortingMode = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchText.value = _searchController.text;
      setState(() {
        isQuerying = _searchText.value.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Widget _buildReorderableList(ThemeData theme) {
    return ReorderableListView.builder(
      itemCount: chatController.chats.length,
      itemBuilder: (context, index) {
        final chat = chatController.chats.reversed.toList()[index];
        return Material(
          key: ValueKey(chat.id),
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: ChatListItem(
              chatId: chat.id,
              onSelectChat: (p0) {},
            ),
            onTap: null,
          ),
        );
      },
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          final reversedList = chatController.chats.reversed.toList();
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final movedChat = reversedList.removeAt(oldIndex);
          reversedList.insert(newIndex, movedChat);
          chatController.chats.assignAll(reversedList.reversed);
          chatController.regenerateChatSortIndex();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索聊天',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              prefixIconConstraints: const BoxConstraints(
                minHeight: 32,
                minWidth: 32,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              suffixIcon: _searchText.value.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        _searchText.value = '';
                      },
                    )
                  : null,
            ),
            style: TextStyle(color: theme.colorScheme.onSurface),
            cursorColor: theme.colorScheme.primary,
          ),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
            tooltip: '新增聊天',
            onSelected: (value) async {
              if (value == 0) {
                final char = await customNavigate<CharacterModel?>(
                    CharacterSelector(),
                    context: context);
                
                if (char != null) {
                  final chat = await chatController.createChatFromCharacter(char);
                  if (widget.onSelectChat != null) {
                    widget.onSelectChat!(chat);
                  } else {
                    customNavigate(ChatDetailPage(chatId: chat.id),
                        context: context);
                  }
                }
              } else if (value == 1) {
                customNavigate(NewChatPage(), context: context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.chat, size: 20),
                    const SizedBox(width: 8),
                    const Text('创建新聊天'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.group, size: 20),
                    const SizedBox(width: 8),
                    const Text('创建新群聊'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _isSortingMode ? Icons.check : Icons.sort,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                _isSortingMode = !_isSortingMode;
                if (!_isSortingMode) {
                  chatController.saveChats();
                }
              });
            },
            tooltip: _isSortingMode ? '完成排序' : '进入排序',
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: theme.appBarTheme.elevation ?? 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isSortingMode
                ? _buildReorderableList(theme)
                : _buildNormalList(theme),
          ),
        ],
      ),
    );
  }
}
