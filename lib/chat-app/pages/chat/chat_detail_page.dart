import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:intl/intl.dart'; // 需要在 pubspec.yaml 中添加 intl 依赖

// 聊天详情界面 Widget
class ChatDetailPage extends StatelessWidget {
  final ChatModel chatModel;

  const ChatDetailPage({Key? key, required this.chatModel}) : super(key: key);

  // 计算总字数
  int get totalWordCount {
    if (chatModel.messages.isEmpty) {
      return 0;
    }
    return chatModel.messages
        .map((m) => m.content.length)
        .reduce((a, b) => a + b);
  }

  // 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天详情'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildChatNameCard(),
          const SizedBox(height: 20),
          _buildStatsCard(),
          const SizedBox(height: 20),
          _buildFileDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildChatNameCard() {
    return Text(
      chatModel.name,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.start,
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '统计信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.message,
              title: '消息总数',
              value: '${chatModel.messages.length} 条',
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.text_fields,
              title: '消息总字数',
              value: '$totalWordCount 字',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '文件详情',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.sd_storage,
              title: '大小',
              value: _formatFileSize(chatModel.file.statSync().size),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.folder,
              title: '路径',
              value: chatModel.file.path,
              isPath: true, // 路径可能很长，需要特殊处理
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.calendar_today,
              title: '修改日期',
              value: DateFormat('yyyy年MM月dd日 HH:mm')
                  .format(chatModel.file.statSync().modified),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon,
      required String title,
      required String value,
      bool isPath = false}) {
    return Row(
      crossAxisAlignment:
          isPath ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            const SizedBox(height: 4),
            SizedBox(
              width: 250, // 限制宽度防止溢出
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                softWrap: true, // 允许长路径换行
              ),
            ),
          ],
        ),
      ],
    );
  }
}
