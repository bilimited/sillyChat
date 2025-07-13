import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/chat/bottom_input_area.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';

class NewChat extends StatefulWidget {
  const NewChat({Key? key, required this.onSubmit}) : super(key: key);

  final Function(String, List<String>) onSubmit;

  @override
  State<NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<NewChat> {
  late final CharacterController _characterController;
  late final ChatController _chatController;
  final ChatOptionController _chatOptionController = Get.find();

  ChatModel get chat => _chatController.defaultChat.value;
  CharacterModel get assistantCharacter =>
      _characterController.getCharacterById(chat.assistantId ?? -1);

  late ChatOptionModel chatOptionModel;

  bool get isFirstCharSelected => chat.assistantId != null;
  bool get isGroupMode => chat.mode == ChatMode.group;
  bool get canCreateNewChat => chat.assistantId != null;

  @override
  void initState() {
    super.initState();
    _characterController = Get.find<CharacterController>();
    _chatController = Get.find<ChatController>();
    _chatController.resetDefaultChat();
    // 这里可以添加更多初始化逻辑
    chatOptionModel = _chatOptionController.defaultOption;
    chat.initOptions(chatOptionModel);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () async {
                final character = await customNavigate<CharacterModel>(
                    CharacterSelector(
                      excludeCharacters: [_characterController.me],
                    ),
                    context: context);
                if (character != null) {
                  _chatController.updateDefaultChat(assistantId: character.id);
                }
              },
              child: Obx(() => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          //const SizedBox(width: 24+48),
                          GestureDetector(
                            onTap: () async {
                              final character =
                                  await customNavigate<CharacterModel>(
                                      CharacterSelector(
                                        excludeCharacters: [
                                          _characterController.me
                                        ],
                                      ),
                                      context: context);
                              if (character != null) {
                                _chatController.updateDefaultChat(
                                    assistantId: character.id);
                              }
                            },
                            child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.secondary, // 边框颜色
                                    width: 3, // 边框宽度
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.45),
                                      blurRadius: 15,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundImage: !isFirstCharSelected
                                      ? null
                                      : Image.file(
                                              File(assistantCharacter.avatar))
                                          .image,
                                  child: !isFirstCharSelected
                                      ? Icon(Icons.account_circle,
                                          size: 120, color: colors.outline)
                                      : null,
                                  backgroundColor: colors.surfaceContainerHigh,
                                )),
                          ),

                          // 待定：创建群聊用
                          // const SizedBox(width: 24),
                          // // 新增圆形加号按钮
                          //   GestureDetector(
                          //   onTap: () async {
                          //     final character =
                          //       await customNavigate<CharacterModel>(
                          //         CharacterSelector(
                          //     excludeCharacters: [_characterController.me],
                          //     ));
                          //     if (character != null) {
                          //     _chatController.updateDefaultChat(
                          //       assistantId: character.id);
                          //     }
                          //   },
                          //   child: Container(
                          //     width: 48,
                          //     height: 48,
                          //     decoration: BoxDecoration(
                          //     shape: BoxShape.circle,
                          //     color: Colors.transparent,
                          //     // border: Border.all(
                          //     //   color: colors.outlineVariant,
                          //     //   width: 2,
                          //     // ),
                          //     ),
                          //     child: Icon(Icons.add,
                          //       color: colors.outline, size: 32),
                          //   ),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        !isFirstCharSelected
                            ? '请选择一个角色'
                            : assistantCharacter.roleName,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: colors.outline,
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        !isFirstCharSelected
                            ? ''
                            : (assistantCharacter.firstMessage != null &&
                                    assistantCharacter.firstMessage!.isNotEmpty)
                                ? '初始对话:${assistantCharacter.firstMessage}'
                                : '无初始对话',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.outline,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.fade,
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      if (isFirstCharSelected)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SillyChatApp.isDesktop()
                                ? colors.surfaceContainerHigh
                                : colors.surface,
                            foregroundColor: colors.outline,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: colors.outline, width: 1),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                          ),
                          onPressed: () {
                            Get.dialog(
                              AlertDialog(
                                title: const Text('切换对话预设'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _chatOptionController
                                        .chatOptions.length,
                                    itemBuilder: (context, index) {
                                      final option = _chatOptionController
                                          .chatOptions[index];
                                      return ListTile(
                                        title: Text(option.name),
                                        onTap: () {
                                          setState(() {
                                            chatOptionModel = option;
                                            chat.initOptions(option);
                                            Get.back();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            '${chatOptionModel.name}',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w400),
                          ),
                        )
                    ],
                  )),
            ),
          ),
        ),
        Container(
          color: SillyChatApp.isDesktop()
              ? colors.surfaceContainerHigh
              : colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Obx(() => BottomInputArea(
                chatId: -1,
                onSendMessage: widget.onSubmit,
                onRetryLastest: () {},
                onToggleGroupWheel: () {},
                onUpdateChat: () {},
                canSend: canCreateNewChat,
                showRetry: false,
                showToolBar: false,
              )),
        )
      ],
    );
  }
}
