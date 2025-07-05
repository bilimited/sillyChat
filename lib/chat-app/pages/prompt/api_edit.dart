import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import '../../models/api_model.dart';

class ApiEditPage extends StatefulWidget {
  final ApiModel? api;

  const ApiEditPage({Key? key, this.api}) : super(key: key);

  @override
  State<ApiEditPage> createState() => _ApiEditPageState();
}

class _ApiEditPageState extends State<ApiEditPage> {
  final _formKey = GlobalKey<FormState>();
  final VaultSettingController controller = Get.find();

  late TextEditingController _apiKeyController;
  late TextEditingController _modelNameController;
  late TextEditingController _urlController;
  late TextEditingController _remarksController;
  late TextEditingController _displayNameController;
  late TextEditingController _modelNameThinkController;
  late ServiceProvider _selectedProvider;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.api?.apiKey ?? '');
    _modelNameController =
        TextEditingController(text: widget.api?.modelName ?? '');
    _urlController = TextEditingController(text: widget.api?.url ?? '');
    _remarksController = TextEditingController(text: widget.api?.remarks ?? '');
    _displayNameController =
        TextEditingController(text: widget.api?.displayName ?? '');
    _modelNameThinkController =
        TextEditingController(text: widget.api?.modelName_think ?? '');
    _selectedProvider = widget.api?.provider ?? ServiceProvider.openai;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _urlController.dispose();
    _remarksController.dispose();
    _displayNameController.dispose();
    _modelNameThinkController.dispose();
    super.dispose();
  }

  void _saveApi() async {
    if (_formKey.currentState!.validate()) {
      final api = ApiModel(
        id: widget.api?.id ?? DateTime.now().millisecondsSinceEpoch,
        apiKey: _apiKeyController.text,
        displayName: _displayNameController.text,
        modelName: _modelNameController.text,
        modelName_think: _modelNameThinkController.text,
        url: _urlController.text,
        provider: _selectedProvider,
        remarks: _remarksController.text,
      );

      if (widget.api == null) {
        await controller.addApi(api);
      } else {
        await controller.updateApi(api);
      }

      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.api == null ? '新建 API' : '编辑 API'),
        actions: widget.api != null
            ? [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _duplicateApi,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmDialog(context),
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            DropdownButtonFormField<ServiceProvider>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: '服务商',
                border: OutlineInputBorder(),
              ),
              items: ServiceProvider.values
                  .map((provider) => DropdownMenuItem(
                        value: provider,
                        child: Text(provider.name),
                      ))
                  .toList(),
              onChanged: (ServiceProvider? value) {
                if (value != null) {
                  setState(() {
                    _selectedProvider = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: '显示名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入显示名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelNameController,
              decoration: const InputDecoration(
                labelText: '模型名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_selectedProvider == ServiceProvider.google) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return '请输入模型名称';
                }
                return null;
              },
            ),
            if (_selectedProvider == ServiceProvider.deepseek) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelNameThinkController,
                decoration: const InputDecoration(
                  labelText: '思考模型名称',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_selectedProvider != ServiceProvider.google)
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 URL';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarksController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveApi,
        child: const Icon(Icons.save),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这个 API 吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.deleteApi(
                  id: widget.api!.id,
                );
                Get.back();
              },
              child: const Text(
                '删除',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _duplicateApi() async {
    final newApi = ApiModel(
      id: DateTime.now().millisecondsSinceEpoch,
      apiKey: _apiKeyController.text,
      displayName: "${_displayNameController.text} (复制)",
      modelName: _modelNameController.text,
      modelName_think: _modelNameThinkController.text,
      url: _urlController.text,
      provider: _selectedProvider,
      remarks: _remarksController.text,
    );

    await controller.addApi(newApi);
    Get.back();
  }
}
