import 'package:flutter/material.dart';

// 应用根组件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 信息列表原型',
      // 设置主题，并启用Material 3设计
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        useMaterial3: true,
      ),
      home: const InfoListPage(),
    );
  }
}

// 数据模型类，用于表示每个列表项的数据
class PromptInfo {
  final String id;
  final String title;
  final int promptCount;
  final String modelName;
  final int regexCount;
  final bool isStreaming;

  PromptInfo({
    required this.id,
    required this.title,
    required this.promptCount,
    required this.modelName,
    required this.regexCount,
    required this.isStreaming,
  });
}

// 列表页面，使用StatefulWidget来管理列表数据的变化
class InfoListPage extends StatefulWidget {
  const InfoListPage({super.key});

  @override
  State<InfoListPage> createState() => _InfoListPageState();
}

class _InfoListPageState extends State<InfoListPage> {
  // 用于存储列表项数据的列表
  final List<PromptInfo> _items = List.generate(
    20,
    (index) => PromptInfo(
      id: 'id_$index',
      title: '创意写作助手 #${index + 1}',
      promptCount: 5 + index * 2,
      modelName: index % 3 == 0 ? 'Gemini Pro' : 'Gemini Ultra',
      regexCount: index % 4,
      isStreaming: index % 2 == 0,
    ),
  );

  // 删除列表项的方法
  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
    // 显示一个简短的提示，告知用户删除成功
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('列表项已删除'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '好的',
          onPressed: () {},
        ),
      ),
    );
  }

  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('紧凑信息列表 (v2)'),
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
        // 使用ListView.builder来构建长列表
        body: Stepper(
          // 当前激活的步骤
          currentStep: _currentStep,
          // 点击步骤的图标触发
          onStepTapped: (step) => setState(() => _currentStep = step),
          // 点击“继续”按钮触发
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            }
          },
          // 点击“取消”按钮触发
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          // 步骤列表
          steps: const [
            Step(
              title: Text('选择计划'),
              content: Center(child: Text('这里是选择计划的内容')),
              isActive: true,
            ),
            Step(
              title: Text('填写信息'),
              content: Center(child: Text('这里是填写信息的内容')),
              isActive: true,
            ),
            Step(
              title: Text('完成支付'),
              content: Center(child: Text('这里是完成支付的内容')),
              isActive: true,
            ),
          ],
        ));
  }
}

// [V2] 自定义列表项Widget - 使用Chip和Wrap来美化
class InfoListItem extends StatelessWidget {
  final PromptInfo item;
  final VoidCallback onDelete;

  const InfoListItem({
    super.key,
    required this.item,
    required this.onDelete,
  });

  // 辅助方法，用于构建带图标和文本的Chip
  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Chip(
      avatar:
          Icon(icon, size: 16, color: theme.colorScheme.onSecondaryContainer),
      label: Text(label),
      labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
      backgroundColor: theme.colorScheme.secondaryContainer,
      // 使用更紧凑的内外边距
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 使用Card作为列表项的容器
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        // 列表项主标题
        title: Text(
          item.title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        // 列表项副标题区域，使用Wrap包裹Chips
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10.0), // 与主标题的间距
          child: Wrap(
            spacing: 8.0, // Chip之间的水平间距
            runSpacing: 6.0, // Chip换行后的垂直间距
            children: [
              // 使用辅助方法创建各个信息Chip
              _buildInfoChip(context, Icons.hub_outlined, item.modelName),
              _buildInfoChip(context, Icons.format_quote_outlined,
                  '提示词: ${item.promptCount}'),
              if (item.regexCount > 0)
                _buildInfoChip(
                    context, Icons.code_rounded, '正则: ${item.regexCount}'),
              if (item.isStreaming)
                _buildInfoChip(context, Icons.bolt_outlined, '流式'),
            ],
          ),
        ),
        // 列表项尾部的Widget，这里放置删除按钮
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: theme.colorScheme.error,
          tooltip: '删除',
          onPressed: onDelete,
        ),
      ),
    );
  }
}
