import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
// 保持你原有的 import
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/chat/goto_chat.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
    );

    // 启动动画
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // 获取最近聊天列表
  List<ChatMetaModel> get recentChat {
    // 这里假设 provider 已经初始化并能同步获取数据，实际情况可能需要放在 build 内部监听或使用 FutureBuilder
    // 为了示例运行顺畅，增加了空值保护
    try {
      return VaultSettingController.of().historyModel.value.chatHistory.map((h) =>
          ChatController.of.getIndex(h)
      ).nonNulls.toList();
    } catch (e) {
      return [];
    }
  }

  void onTapChat(String path) {
    GotoChat.byPath(path);
  }

  void gotoCreateChat() async {
    // 增加一点按键反馈延迟，体验更好
    final chat = await ChatController.of.createQuickChat(SettingController.of.getChatPathSync());
    GotoChat.byPath(chat.file.path);
  }

  // 获取时段问候语
  String get _greetingMessage {
    String userName = CharacterController.of.me.roleName;

    final hour = DateTime.now().hour;
    if (hour < 5) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  late final _greetingSubtitle = greetings[Random().nextInt(greetings.length)];

  List<String> greetings = [
    "这里写点啥好捏?","喵喵喵!","欢迎回来。"
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chats = recentChat;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // --- Header Section ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greetingMessage,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _greetingSubtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- Quick Action Button ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildCreateChatButton(theme, colorScheme),
                ),
              ),

              const SizedBox(height: 40),

              // --- Recent Chats Title ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  '最近聊天',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Recent Chats List with Fade Mask ---
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: chats.isEmpty
                      ? _buildEmptyState(theme, colorScheme)
                      : ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.white, Colors.transparent],
                              stops: [0.0, 0.85, 1.0], // 底部 15% 渐变透明
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: chats.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            // 底部留白，防止被遮罩完全遮挡
                            padding: const EdgeInsets.only(bottom: 40),
                            itemBuilder: (context, index) {
                              return _buildChatCard(chats[index], theme, colorScheme);
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildCreateChatButton(ThemeData theme, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      elevation: 0, // 扁平化设计，也可以设为 2
      child: InkWell(
        onTap: gotoCreateChat,
        borderRadius: BorderRadius.circular(16),
        splashColor: colorScheme.primary.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '快速开始',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '创建一个新的话题',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: colorScheme.onPrimary,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard(ChatMetaModel meta, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow, // 稍微不同于背景的颜色
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onTapChat(meta.path),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar Placeholder
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withOpacity(0.2),
                child: Text(
                  meta.name.isNotEmpty ? meta.name.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.lastMessage ?? '暂无消息',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有聊天记录',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}