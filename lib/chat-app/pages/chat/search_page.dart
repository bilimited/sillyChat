import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';

// 定义一个新的搜索结果数据结构
class _SearchResult {
  final String path;
  final ChatModel chat;
  final MessageModel message;
  _SearchResult(this.path, this.chat, this.message);
}

class SearchPage extends StatefulWidget {
  // 1. 修改输入参数：从 List<ChatModel> 变为 String searchPath
  final String searchPath;
  final void Function(String, MessageModel, ChatModel) onMessageTap;
  final bool isdesktop;

  const SearchPage({
    Key? key,
    required this.searchPath, // 必须提供搜索路径
    required this.onMessageTap,
    this.isdesktop = false,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 使用 TextEditingController 来管理输入框文本
  final _searchController = TextEditingController();

  // 状态变量
  bool _isSearching = false;
  List<_SearchResult> _results = [];

  // 新增：用于显示搜索进度的计数器
  int _searchedFilesCount = 0;
  int _totalMessagesScanned = 0;

  // 依赖注入的 Controller
  final CharacterController _characterController = Get.find();

  @override
  void dispose() {
    _searchController.dispose(); // 及时释放资源
    super.dispose();
  }

  // 2. 重构搜索逻辑为一个独立的异步方法
  void _startSearch() async {
    // 收起键盘
    FocusScope.of(context).unfocus();

    final query = _searchController.text;
    if (query.isEmpty) {
      // 如果搜索内容为空，可以提示用户或不做任何事
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入搜索内容')),
      );
      return;
    }

    // A. 重置状态并开始搜索
    setState(() {
      _isSearching = true;
      _results.clear();
      _searchedFilesCount = 0;
      _totalMessagesScanned = 0;
    });

    final directory = Directory(widget.searchPath);
    if (!await directory.exists()) {
      // 路径不存在的错误处理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('错误：路径不存在 ${widget.searchPath}')),
      );
      setState(() {
        _isSearching = false;
      });
      return;
    }

    // B. 递归遍历文件系统
    // 使用 dir.list() 返回一个 Stream，可以异步地处理每个文件
    try {
      final fileStream = directory.list(recursive: true);
      await for (final entity in fileStream) {
        // 确保是 .chat 文件
        if (entity is File && entity.path.endsWith('.chat')) {
          _searchedFilesCount++;

          try {
            // C. 读取和反序列化文件
            final jsonString = await entity.readAsString();
            final chat = ChatModel.fromJson(jsonDecode(jsonString));

            _totalMessagesScanned += chat.messages.length;

            // D. 在消息中执行搜索
            for (final msg in chat.messages) {
              if (msg.content.toLowerCase().contains(query.toLowerCase())) {
                _results.add(_SearchResult(entity.path, chat, msg));
              }
            }
            // E. 实时更新UI
            // 每处理完一个文件就调用 setState，刷新进度和结果列表
            setState(() {});
          } catch (e) {
            // 文件读取或JSON解析失败，可以选择性地忽略或报告错误
            print('处理文件失败 ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      print('遍历文件时发生错误: $e');
    }

    // F. 搜索完成
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isdesktop
          ? null
          : AppBar(
              title: const Text('搜索消息'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索内容',
                // 3. 新增搜索按钮
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isSearching ? null : _startSearch, // 搜索时禁用按钮
                ),
              ),
              // 提交时也触发搜索
              onSubmitted: (_) => _isSearching ? null : _startSearch(),
            ),
          ),

          // 4. 新增：显示详细的搜索状态
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isSearching
                    ? '正在搜索... 已扫描 $_searchedFilesCount 个文件'
                    : '已搜索 $_searchedFilesCount 个文件，在 $_totalMessagesScanned 条消息中找到 ${_results.length} 个匹配项',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isSearching && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('无结果'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, idx) {
                          final result = _results[idx];
                          final msg = result.message;
                          final chat = result.chat;
                          final character = _characterController
                              .getCharacterById(msg.senderId);

                          final query = _searchController.text.toLowerCase();
                          final content = msg.content.replaceAll('\n', ' ');
                          final contentLower = content.toLowerCase();
                          final matchIndex = contentLower.indexOf(query);

                          // 高亮显示匹配的关键字
                          Widget titleWidget;
                          if (matchIndex != -1) {
                            final start =
                                matchIndex - 20 >= 0 ? matchIndex - 20 : 0;
                            final partContentBefore =
                                content.substring(start, matchIndex);
                            final partContentAfter =
                                content.substring(matchIndex + query.length);
                            titleWidget = RichText(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: [
                                  if (start > 0) const TextSpan(text: '...'),
                                  TextSpan(text: partContentBefore),
                                  TextSpan(
                                    text: content.substring(
                                        matchIndex, matchIndex + query.length),
                                    style: TextStyle(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: partContentAfter),
                                ],
                              ),
                            );
                          } else {
                            // 理论上不会走到这里，因为结果都是匹配的
                            titleWidget = Text(
                              content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            );
                          }

                          return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    ImageUtils.getProvider(character.avatar),
                              ),
                              title: titleWidget,
                              subtitle: Text(
                                chat.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              // 5. 移除书签逻辑，只保留 Pin
                              trailing: msg.isPinned
                                  ? const Icon(Icons.push_pin,
                                      color: Colors.orange)
                                  : null,
                              onTap: () {
                                widget.onMessageTap(result.path, msg, chat);
                                if (!SillyChatApp.isDesktop()) {
                                  Get.back();
                                }
                              });
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
