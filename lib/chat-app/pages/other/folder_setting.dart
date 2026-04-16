import 'package:flutter/material.dart';
// 假设你的模型文件在这里导入
// import 'path_to_your_model/folder_setting_model.dart';

class FolderSettingPage extends StatefulWidget {
  final String path; // 文件夹所在路径（不包含配置文件名）

  const FolderSettingPage({Key? key, required this.path}) : super(key: key);

  @override
  State<FolderSettingPage> createState() => _FolderSettingPageState();
}

class _FolderSettingPageState extends State<FolderSettingPage> {
  // 1. 声明数据模型
  // late FolderSettingModel _settingModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // 2. 初始化方法
  Future<void> _initData() async {
    setState(() => _isLoading = true);
    
    // TODO: 这里编写加载数据的逻辑
    // 如果是编辑模式，根据 widget.folderId 获取数据
    // 如果是新建模式，初始化一个空模型
    
    await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 3. 释放资源方法
  @override
  void dispose() {
    // TODO: 在这里销毁 TextEditingController 等资源
    super.dispose();
  }

  // 4. 保存方法
  void _onSave() {
    // TODO: 校验表单并调用 API 保存
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在保存设置...')),
    );
    
    // 成功后返回上一页
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // 使用主题背景色
      appBar: AppBar(
        title: const Text('文件夹设置'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        actions: [
          // 备用保存按钮
          IconButton(
            onPressed: _onSave,
            icon: const Icon(Icons.check),
            tooltip: '保存',
          ),
        ],
      ),
      
      // 内容区域
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // TODO: 在这里添加你的表单组件、文本框、选择器等
                  const Center(
                    child: Text(
                      '设置内容请填充在此处',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

      // 悬浮保存按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onSave,
        label: const Text('保存设置'),
        icon: const Icon(Icons.save),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}