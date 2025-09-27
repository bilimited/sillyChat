import 'package:flutter/material.dart';
// import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';

// 主设置页面
class ChatCompressionSettingsPage extends StatefulWidget {
  final ChatCompressionSettings settings_;
  final ValueChanged<ChatCompressionSettings> onChanged;
  const ChatCompressionSettingsPage({
    super.key,
    required this.settings_,
    required this.onChanged,
  });

  @override
  State<ChatCompressionSettingsPage> createState() =>
      _ChatCompressionSettingsPageState();
}

class ChatCompressionSettings {
  final String
      separatorType; // e.g., 'space', 'newline', 'double newline', 'custom'
  final String separatorValue;

  final bool putSystemInjectionAfterChatHistory;

  final String onChatHistoryType; // mixin, seperate, squash
  final String squashRole; // system, user, assistant

  final String userPrefix;
  final String userSuffix;
  final String assistantPrefix;
  final String assistantSuffix;
  final String systemPrefix;
  final String systemSuffix;

  const ChatCompressionSettings({
    this.separatorType = 'double newline',
    this.separatorValue = '\n\n',
    this.putSystemInjectionAfterChatHistory = false,
    this.onChatHistoryType = 'mixin',
    this.squashRole = 'assistant',
    this.userPrefix = '{{user}}: ',
    this.userSuffix = '',
    this.assistantPrefix = '剧情: ',
    this.assistantSuffix = '',
    this.systemPrefix = '',
    this.systemSuffix = '',
  });

  factory ChatCompressionSettings.fromJson(Map<String, dynamic> json) {
    return ChatCompressionSettings(
      separatorType: json['seperator_type'] ?? 'double newline',
      separatorValue: json['seperator_value'] ?? '\n\n',
      putSystemInjectionAfterChatHistory:
          json['put_system_injection_after_chat_history'] ?? false,
      onChatHistoryType: json['on_chat_history_type'] ?? 'mixin',
      squashRole: json['squash_role'] ?? 'assistant',
      userPrefix: json['user_prefix'] ?? '{{user}}: ',
      userSuffix: json['user_suffix'] ?? '',
      assistantPrefix: json['assistant_prefix'] ?? '剧情: ',
      assistantSuffix: json['assistant_suffix'] ?? '',
      systemPrefix: json['system_prefix'] ?? '',
      systemSuffix: json['system_suffix'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seperator_type': separatorType,
      'seperator_value': separatorValue,
      'put_system_injection_after_chat_history':
          putSystemInjectionAfterChatHistory,
      'on_chat_history_type': onChatHistoryType,
      'squash_role': squashRole,
      'user_prefix': userPrefix,
      'user_suffix': userSuffix,
      'assistant_prefix': assistantPrefix,
      'assistant_suffix': assistantSuffix,
      'system_prefix': systemPrefix,
      'system_suffix': systemSuffix,
    };
  }

  // 支持更新（返回新实例）
  ChatCompressionSettings copyWith({
    String? separatorType,
    String? separatorValue,
    bool? putSystemInjectionAfterChatHistory,
    String? onChatHistoryType,
    String? squashRole,
    String? userPrefix,
    String? userSuffix,
    String? assistantPrefix,
    String? assistantSuffix,
    String? systemPrefix,
    String? systemSuffix,
  }) {
    return ChatCompressionSettings(
      separatorType: separatorType ?? this.separatorType,
      separatorValue: separatorValue ?? this.separatorValue,
      putSystemInjectionAfterChatHistory: putSystemInjectionAfterChatHistory ??
          this.putSystemInjectionAfterChatHistory,
      onChatHistoryType: onChatHistoryType ?? this.onChatHistoryType,
      squashRole: squashRole ?? this.squashRole,
      userPrefix: userPrefix ?? this.userPrefix,
      userSuffix: userSuffix ?? this.userSuffix,
      assistantPrefix: assistantPrefix ?? this.assistantPrefix,
      assistantSuffix: assistantSuffix ?? this.assistantSuffix,
      systemPrefix: systemPrefix ?? this.systemPrefix,
      systemSuffix: systemSuffix ?? this.systemSuffix,
    );
  }

  ChatCompressionSettings copyAllFrom(ChatCompressionSettings other) {
    return copyWith(
      separatorType: other.separatorType,
      separatorValue: other.separatorValue,
      putSystemInjectionAfterChatHistory:
          other.putSystemInjectionAfterChatHistory,
      onChatHistoryType: other.onChatHistoryType,
      squashRole: other.squashRole,
      userPrefix: other.userPrefix,
      userSuffix: other.userSuffix,
      assistantPrefix: other.assistantPrefix,
      assistantSuffix: other.assistantSuffix,
      systemPrefix: other.systemPrefix,
      systemSuffix: other.systemSuffix,
    );
  }
}

class _ChatCompressionSettingsPageState
    extends State<ChatCompressionSettingsPage> {
  // 表单控制对象
  final _formKey = GlobalKey<FormState>();

  String _separatorType = 'double newline';
  String _separatorValue = '\n\n';
  bool _putSystemInjectionAfterChatHistory = false;
  String _onChatHistoryType = 'mixin';
  String _squashRole = 'assistant';
  String _userPrefix = '{{user}}: ';
  String _userSuffix = '';
  String _assistantPrefix = '剧情: ';
  String _assistantSuffix = '';
  String _systemPrefix = '';
  String _systemSuffix = '';
  // 设置项状态（对应原 JS 中的 settings）
  late ChatCompressionSettings settings;
  @override
  void initState() {
    super.initState();
    settings = widget.settings_;
  }

  // 分隔符类型选项
  final List<String> separatorTypes = [
    'space',
    'newline',
    'double newline',
    'custom'
  ];
  final Map<String, String> separatorLabels = {
    'space': '空格',
    'newline': '换行',
    'double newline': '双换行',
    'custom': '自定义',
  };

  // 聊天历史处理方式
  final List<String> historyTypes = ['mixin', 'seperate', 'squash'];
  final Map<String, String> historyLabels = {
    'mixin': '与其他提示词混合',
    'seperate': '与其他提示词隔离',
    'squash': '单独压缩为一条消息',
  };

  // 压缩角色选项
  final List<String> squashRoles = ['system', 'user', 'assistant'];
  final Map<String, String> squashRoleLabels = {
    'system': '系统',
    'user': '用户',
    'assistant': '助手',
  };

  // 显示帮助弹窗
  void showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于“将 D⚙ 移至末尾”'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '根据 '),
                  WidgetSpan(
                    child: Text(
                      '部分预设作者的说法',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextSpan(
                      text: '，Gemini 和 Claude 不需要将系统条目插入聊天记录中，反而会影响连贯性。\n\n'),
                ]),
              ),
              Text(
                '此选项会将注入的系统消息（D⚙）按顺序移动到聊天记录末尾（D0），而不是保留在原始深度。',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '虽然无需角色卡作者手动设为 D0，但仍需适配。如果角色设定随剧情发展，放置在深度条目中，则开启此选项可能导致角色固化。',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 更新 separator.value 根据 type
  void updateSeparatorValue() {
    final String type = settings.separatorType;
    switch (type) {
      case 'space':
        _separatorValue = ' ';
        break;
      case 'newline':
        _separatorValue = '\n';
        break;
      case 'double newline':
        _separatorValue = '\n\n';
        break;
      default:
        // custom: 不改变 value，保留用户输入
        break;
    }
    setState(() {});
  }

  void saveSettings() {
    // 构造新 settings 实例
    final updatedSettings = settings.copyWith(
      separatorType: _separatorType,
      separatorValue: _separatorValue,
      putSystemInjectionAfterChatHistory: _putSystemInjectionAfterChatHistory,
      onChatHistoryType: _onChatHistoryType,
      squashRole: _squashRole,
      userPrefix: _userPrefix,
      userSuffix: _userSuffix,
      assistantPrefix: _assistantPrefix,
      assistantSuffix: _assistantSuffix,
      systemPrefix: _systemPrefix,
      systemSuffix: _systemSuffix,
    );
    // 更新整个 options
    widget.onChanged(widget.settings_.copyAllFrom(updatedSettings)); // 回调通知外层保存
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('压缩相邻消息设置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- 消息分隔符 ---
            Text('消息分隔符', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: settings.separatorType,
              items: separatorTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(separatorLabels[type]!),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _separatorType = value;
                    updateSeparatorValue();
                    saveSettings();                    
                  });
                }
              },
              decoration: const InputDecoration(labelText: '选择分隔符类型'),
            ),
            const SizedBox(height: 8),

            // 自定义分隔符输入框
            if (_separatorType == 'custom')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('自定义分隔符'),
                  TextFormField(
                    initialValue: settings.separatorValue,
                    onChanged: (value) {
                      _separatorValue = value;
                      saveSettings();
                    },
                    decoration: const InputDecoration(
                      hintText: '例如：\\n---\\n',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            const Divider(),

            // --- 系统消息移动到末尾 ---
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text("将 D⚙ (系统深度条目) 按序移到聊天记录后"),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 16),
                        onPressed: showHelpDialog,
                        tooltip: '显示帮助',
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.putSystemInjectionAfterChatHistory || _putSystemInjectionAfterChatHistory,
                  onChanged: (value) {
                    setState(() {
                      _putSystemInjectionAfterChatHistory = value;
                      saveSettings();
                    });
                  },
                ),
              ],
            ),

            const Divider(),

            // --- 聊天历史处理方式 ---
            Text('聊天历史处理方式', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: settings.onChatHistoryType,
              items: historyTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(historyLabels[type]!),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  // _onChatHistoryType = value;
                  // saveSettings();
                  setState(() {
                    _onChatHistoryType = value;
                    saveSettings();
                  });
                }
              },
              decoration: const InputDecoration(labelText: '处理方式'),
            ),

            const SizedBox(height: 16),

            // --- 压缩角色选择（仅当 squash 时显示）---
            if (_onChatHistoryType == 'squash')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('压缩角色'),
                  DropdownButtonFormField<String>(
                    value: settings.squashRole,
                    items: squashRoles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(squashRoleLabels[role]!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _squashRole = value;
                        saveSettings();
                        setState(() {});
                      }
                    },
                    decoration: const InputDecoration(labelText: '选择压缩后的角色'),
                  ),
                  const SizedBox(height: 16),

                  const Text('前缀与后缀设置',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // 用户前缀
                  const Text('用户前缀'),
                  TextFormField(
                    initialValue: settings.userPrefix,
                    onChanged: (value) {
                      _userPrefix = value;
                      saveSettings();
                    },
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 8),
                  const Text('用户后缀'),
                  TextFormField(
                    initialValue: settings.userSuffix,
                    onChanged: (value) {
                      _userSuffix = value;
                      saveSettings();
                    },
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 8),
                  const Text('助手前缀'),
                  TextFormField(
                    initialValue: settings.assistantPrefix,
                    onChanged: (value) {
                      _assistantPrefix = value;
                      saveSettings();
                    },
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 8),
                  const Text('助手后缀'),
                  TextFormField(
                    initialValue: settings.assistantSuffix,
                    onChanged: (value) {
                      _assistantSuffix = value;
                      saveSettings();
                    },
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 8),
                  const Text('系统前缀'),
                  TextFormField(
                    initialValue: settings.systemPrefix,
                    onChanged: (value) {
                      _systemPrefix = value;
                      saveSettings();
                    },
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 8),
                  const Text('系统后缀'),
                  TextFormField(
                    initialValue: settings.systemSuffix,
                    onChanged: (value) {
                      _systemSuffix = value;
                      saveSettings();
                    },
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
