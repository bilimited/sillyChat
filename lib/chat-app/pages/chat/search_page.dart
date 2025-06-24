import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:get/get.dart';

class SearchPage extends StatefulWidget {
  final List<ChatModel> chats;
  final void Function(MessageModel, ChatModel) onMessageTap;
  final bool isdesktop;

  const SearchPage({
    Key? key,
    required this.chats,
    required this.onMessageTap,
    this.isdesktop = false,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';
  bool _loading = false;
  List<_SearchResult> _results = [];

  CharacterController _characterController = Get.find();
  @override
  void initState() {
    super.initState();
    _search('');
  }

  void _search(String query) async {
    setState(() {
      _query = query;
      _loading = true;
    });

    List<_SearchResult> results = [];
    for (final chat in widget.chats) {
      for (final msg in chat.messages) {
        if (query.isEmpty) {
          if (msg.bookmark == true) {
            results.add(_SearchResult(chat, msg));
          }
        } else {
          if (msg.content.toLowerCase().contains(query.toLowerCase())) {
            results.add(_SearchResult(chat, msg));
          }
        }
      }
    }

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool multiChat = widget.chats.length > 1;
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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索内容',
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          // 新增：显示搜索结果总条数
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '共找到 ${_results.length} 条结果',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('无结果'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, idx) {
                        final result = _results[idx];
                        final msg = result.message;
                        final chat = result.chat;
                        final character =
                            _characterController.getCharacterById(msg.sender);

                        final query = _query.toLowerCase();
                        final content = msg.content.replaceAll('\n', ' ');
                        final contentLower = content.toLowerCase();
                        final matchIndex = contentLower.indexOf(query);
                        String partContentBefore = '';
                        String partContentAfter = '';
                        if (query.isNotEmpty && matchIndex != -1) {
                          final start =
                              matchIndex - 20 >= 0 ? matchIndex - 20 : 0;
                          partContentBefore =
                              content.substring(start, matchIndex);
                          partContentAfter =
                              content.substring(matchIndex + query.length);
                        }
                        return ListTile(
                          leading: CircleAvatar(
                            // 头像占位
                            backgroundImage:
                                Image.file(File(character.avatar)).image,
                          ),
                          title: query.isNotEmpty && matchIndex != -1
                              ? RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    children: [
                                      TextSpan(text: partContentBefore),
                                      TextSpan(
                                        text: content.substring(matchIndex,
                                            matchIndex + query.length),
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
                                )
                              : Text(msg.content,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: multiChat
                              ? Text(
                                  chat.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                          trailing: msg.bookmark
                              ? const Icon(Icons.bookmark, color: Colors.orange)
                              : null,
                          onTap: () => widget.onMessageTap(msg, chat),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final ChatModel chat;
  final MessageModel message;
  _SearchResult(this.chat, this.message);
}
