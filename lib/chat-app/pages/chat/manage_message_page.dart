import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:get/get.dart';

class ManageMessagePage extends StatefulWidget {
  final ChatModel chat;
  final ChatSessionController chatSessionController;

  const ManageMessagePage(
      {Key? key, required this.chat, required this.chatSessionController})
      : super(key: key);

  @override
  State<ManageMessagePage> createState() => _ManageMessagePageState();
}

// TODO:添加高级搜索，如按角色搜索，范围搜索

class _ManageMessagePageState extends State<ManageMessagePage> {
  final Map<int, bool> _expandedMessages = {};
  final CharacterController _characterController = Get.find();
  final ChatController _chatController = Get.find();

  // --- Search Integration ---
  final TextEditingController _searchController = TextEditingController();
  List<MessageModel> _filteredMessages = [];
  String _query = '';

  // --- Multi-select State ---
  bool _isMultiSelecting = false;
  List<MessageModel> _selectedMessages = [];

  @override
  void initState() {
    super.initState();
    // Initially, show all messages
    _filteredMessages = widget.chat.messages.toList();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_performSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text;
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _filteredMessages = widget.chat.messages.toList();
      } else {
        _filteredMessages = widget.chat.messages.where((message) {
          return message.content.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      _expandedMessages.clear();
      // Ensure selected messages are valid after filtering
      _selectedMessages.removeWhere((msg) => !_filteredMessages.contains(msg));
      if (_selectedMessages.isEmpty) {
        _isMultiSelecting = false;
      }
    });
  }

  // --- Multi-select Logic ---

  Future<void> _updateChat() async {
    await widget.chatSessionController.saveChat();
    _performSearch(); // Refresh the list to reflect changes
  }

  void _startMultiSelect(MessageModel firstSelectedMessage) {
    if (!_filteredMessages.contains(firstSelectedMessage)) return;
    setState(() {
      _isMultiSelecting = true;
      _selectedMessages = [firstSelectedMessage];
    });
  }

  void _onMultiSelectMessage(MessageModel message) {
    setState(() {
      if (_selectedMessages.contains(message)) {
        _selectedMessages.remove(message);
        if (_selectedMessages.isEmpty) {
          _isMultiSelecting = false;
        }
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  void _cancelMultiSelect() {
    setState(() {
      _isMultiSelecting = false;
      _selectedMessages.clear();
    });
  }

  /// Builds a RichText widget with highlighted search query.
  Widget _buildHighlightedText(MessageModel message, BuildContext context,
      {bool isExpand = true}) {
    final theme = Theme.of(context);
    final text = message.content;
    final query = _query;

    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      // Use theme font
      return Text(
        text,
        maxLines: isExpand ? null : 2,
        overflow: isExpand ? TextOverflow.visible : TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: message.isPinned ? FontWeight.bold : FontWeight.normal,
          color: message.isPinned
              ? Colors.orange
              : message.isHidden
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurface,
        ),
      );
    }

    final List<TextSpan> spans = [];
    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final int matchIndex = textLower.indexOf(queryLower, start);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (matchIndex > start) {
        spans.add(TextSpan(text: text.substring(start, matchIndex)));
      }

      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: theme.textTheme.bodyMedium?.copyWith(
            backgroundColor: theme.colorScheme.primaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = matchIndex + query.length;
    }

    // Use theme font as base style
    final isPinned = message.isPinned;
    final isHidden = message.isHidden;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: isPinned ? FontWeight.bold : FontWeight.normal,
      color: isPinned
          ? Colors.orange
          : isHidden
              ? theme.colorScheme.outline
              : theme.colorScheme.onSurface,
    );

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: isExpand ? null : 2,
      overflow: isExpand ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    if (_isMultiSelecting) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelMultiSelect,
        ),
        title: Text('已选择${_selectedMessages.length}条消息'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
      );
    }

    return AppBar(
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '在聊天中搜索...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            filled: true,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
          ),
        ),
      ),
      elevation: 0,
    );
  }

  Widget _buildFloatingButtons() {
    if (!_isMultiSelecting) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 80, // Position above bottom bar
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: '选择上方所有',
            onPressed: () {
              if (_selectedMessages.isEmpty) return;
              // Use a sorted copy to determine chronological order
              final sortedAllMessages = List.from(widget.chat.messages)
                ..sort((a, b) => a.time.compareTo(b.time));
              final sortedSelected = List.from(_selectedMessages)
                ..sort((a, b) => a.time.compareTo(b.time));

              int currentIndex = sortedAllMessages
                  .indexWhere((msg) => msg.id == sortedSelected.first.id);

              if (currentIndex != -1) {
                final Set<MessageModel> toAdd = {};
                for (int i = 0; i <= currentIndex; i++) {
                  // Only add if visible in the current filtered list
                  if (_filteredMessages.contains(sortedAllMessages[i])) {
                    toAdd.add(sortedAllMessages[i]);
                  }
                }
                setState(() => _selectedMessages.addAll(toAdd));
                // Remove duplicates from _selectedMessages
                _selectedMessages = _selectedMessages.toSet().toList();
              }
            },
            child: Icon(Icons.arrow_upward, size: 20, color: colors.onPrimary),
            backgroundColor: colors.primary,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: '选择下方所有',
            onPressed: () {
              if (_selectedMessages.isEmpty) return;
              final sortedAllMessages = List.from(widget.chat.messages)
                ..sort((a, b) => a.time.compareTo(b.time));
              final sortedSelected = List.from(_selectedMessages)
                ..sort((a, b) => a.time.compareTo(b.time));

              int currentIndex = sortedAllMessages
                  .indexWhere((msg) => msg.id == sortedSelected.last.id);

              if (currentIndex != -1) {
                final Set<MessageModel> toAdd = {};
                for (int i = currentIndex; i < sortedAllMessages.length; i++) {
                  if (_filteredMessages.contains(sortedAllMessages[i])) {
                    toAdd.add(sortedAllMessages[i]);
                  }
                }
                setState(() => _selectedMessages.addAll(toAdd));
                _selectedMessages = _selectedMessages.toSet().toList();
              }
            },
            child:
                Icon(Icons.arrow_downward, size: 20, color: colors.onPrimary),
            backgroundColor: colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (!_isMultiSelecting) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: "复制",
            onPressed: () {
              _chatController.putMessageToClipboard(
                  widget.chat.messages, _selectedMessages);
              Get.showSnackbar(GetSnackBar(
                  message: "复制了${_selectedMessages.length}条消息",
                  duration: const Duration(seconds: 2)));
              _cancelMultiSelect();
            },
            icon: Icon(Icons.copy_all, color: colors.onSurfaceVariant),
          ),
          IconButton(
            tooltip: "剪切",
            onPressed: () {
              _chatController.putMessageToClipboard(
                  widget.chat.messages, _selectedMessages);
              widget.chatSessionController.removeMessages(_selectedMessages);
              Get.showSnackbar(GetSnackBar(
                  message: "剪切了${_selectedMessages.length}条消息",
                  duration: const Duration(seconds: 2)));
              _updateChat();
              _cancelMultiSelect();
            },
            icon: Icon(Icons.cut, color: colors.onSurfaceVariant),
          ),
          IconButton(
            tooltip: "隐藏",
            onPressed: () {
              for (final msg in _selectedMessages) {
                msg.visbility = MessageVisbility.hidden;
              }
              _updateChat();
              _cancelMultiSelect();
            },
            icon: Icon(Icons.visibility_off, color: colors.onSurfaceVariant),
          ),
          IconButton(
            tooltip: "订固",
            onPressed: () {
              for (final msg in _selectedMessages) {
                msg.visbility = MessageVisbility.pinned;
              }
              _updateChat();
              _cancelMultiSelect();
            },
            icon: Icon(Icons.push_pin, color: colors.onSurfaceVariant),
          ),
          IconButton(
            tooltip: '取消隐藏/订固',
            onPressed: () {
              for (final msg in _selectedMessages) {
                msg.visbility = MessageVisbility.common;
              }
              _updateChat();
              _cancelMultiSelect();
            },
            icon: Icon(Icons.remove_red_eye, color: colors.onSurfaceVariant),
          ),
          IconButton(
            tooltip: "删除",
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('删除消息'),
                  content: Text('确定要删除这 ${_selectedMessages.length} 条消息吗？'),
                  actions: [
                    TextButton(
                        onPressed: () => Get.back(), child: const Text('取消')),
                    TextButton(
                      child: const Text('确认'),
                      style:
                          TextButton.styleFrom(foregroundColor: colors.error),
                      onPressed: () {
                        Get.back(); // Dismiss dialog first
                        widget.chatSessionController
                            .removeMessages(_selectedMessages);
                        _updateChat();
                        _cancelMultiSelect();
                      },
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.delete, color: colors.error),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isMultiSelecting,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _cancelMultiSelect();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        bottomNavigationBar: _isMultiSelecting ? _buildBottomActions() : null,
        body: Stack(
          children: [
            Column(
              children: [
                if (_query.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '找到 ${_filteredMessages.length} 条结果',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ),
                Expanded(
                  child: _filteredMessages.isEmpty
                      ? Center(
                          child: Text(_query.isEmpty ? '没有聊天记录' : '没有找到结果'))
                      : ListView.separated(
                          itemCount: _filteredMessages.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: theme.dividerColor,
                            indent: 80,
                          ),
                          itemBuilder: (context, index) {
                            final message = _filteredMessages[index];
                            final messageKey = message.hashCode;
                            final isExpanded =
                                _expandedMessages[messageKey] ?? false;
                            final character = _characterController
                                .getCharacterById(message.senderId);
                            final isSelected =
                                _selectedMessages.contains(message);
                            final bool isLongText =
                                message.content.contains('\n');

                            return Material(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                      .withOpacity(0.4)
                                  : theme.colorScheme.surface,
                              child: InkWell(
                                onLongPress: () => _startMultiSelect(message),
                                onTap: () {
                                  if (_isMultiSelecting) {
                                    _onMultiSelectMessage(message);
                                  } else if (isLongText) {
                                    setState(() {
                                      _expandedMessages[messageKey] =
                                          !isExpanded;
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // --- Multi-select Checkbox ---
                                      if (_isMultiSelecting)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 12.0),
                                          child: Icon(
                                            isSelected
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      CircleAvatar(
                                        backgroundImage: ImageUtils.getProvider(
                                            character.avatar),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: AnimatedSize(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                curve: Curves.easeInOutCirc,
                                                child: _buildHighlightedText(
                                                    message, context,
                                                    isExpand: isExpanded),
                                              ),
                                            ),
                                            if (isLongText &&
                                                !_isMultiSelecting)
                                              SizedBox(
                                                width: 28,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Icon(
                                                    isExpanded
                                                        ? Icons.expand_less
                                                        : Icons.expand_more,
                                                    color: theme
                                                        .colorScheme.primary,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            _buildFloatingButtons(),
          ],
        ),
      ),
    );
  }
}
