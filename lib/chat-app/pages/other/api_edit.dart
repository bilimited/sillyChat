import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandlerFactory.dart';
import 'package:flutter_example/main.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import '../../models/api_model.dart';
// 如果原先引入了 option_input.dart，由于去掉了 modelName 字段，现在可以不再需要它，但为了兼容保留亦可

class ApiEditPage extends StatefulWidget {
  final ApiModel? api;

  const ApiEditPage({Key? key, this.api}) : super(key: key);

  @override
  State<ApiEditPage> createState() => _ApiEditPageState();
}

class _ApiEditPageState extends State<ApiEditPage> {
  final _formKey = GlobalKey<FormState>();
  final VaultSettingController controller = Get.find();

  // 移除了 UI 对此字段的依赖，仅保留作为底层兼容
  String modelName = "";
  List<String> modelList = [];

  late TextEditingController _apiKeyController;
  late TextEditingController _urlController;
  late TextEditingController _remarksController;
  late TextEditingController _displayNameController;
  late TextEditingController _requestBodyController;
  late ServiceType _selectedProvider;

  bool _isPanelExpanded = false;
  bool isFetchingModelList = false;
  bool isFetchingBalance = false;
  bool isTesting = false;
  bool? isTestSuccess; // null 代表未测试

  String? balanceResult;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.api?.apiKey ?? '');
    modelName = widget.api?.modelName ?? '';
    _urlController = TextEditingController(text: widget.api?.url ?? '');
    _remarksController = TextEditingController(text: widget.api?.remarks ?? '');
    // 节点显示名称
    _displayNameController =
        TextEditingController(text: widget.api?.displayName ?? '');
    _requestBodyController =
        TextEditingController(text: widget.api?.requestBody ?? '');

    _selectedProvider = widget.api?.provider ?? ServiceType.openai;
    // 初始化并深拷贝模型列表，防止意外污染原对象
    modelList = List<String>.from(widget.api?.models ?? []);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _urlController.dispose();
    _remarksController.dispose();
    _displayNameController.dispose();
    _requestBodyController.dispose();
    super.dispose();
  }

  void _saveApi() async {
    if (_formKey.currentState!.validate()) {
      // 自动维护底层 modelName（兼容旧逻辑）：如果模型列表有数据，取第一个
      String targetModelName =
          modelList.isNotEmpty ? modelList.first : modelName;

      final api = ApiModel(
        id: widget.api?.id ?? DateTime.now().millisecondsSinceEpoch,
        apiKey: _apiKeyController.text,
        displayName: _displayNameController.text,
        modelName: targetModelName,
        url: _selectedProvider.defaultUrl.isEmpty
            ? _urlController.text
            : _selectedProvider.defaultUrl,
        provider: _selectedProvider,
        remarks: _remarksController.text,
        requestBody: _requestBodyController.text.isNotEmpty
            ? _requestBodyController.text
            : null,
        models: modelList,
      );

      if (widget.api == null) {
        await controller.addApi(api);
      } else {
        await controller.updateApi(api);
      }
    }
  }

  Future<bool> _sendTestMessage() async {
    if (_apiKeyController.text.isEmpty) {
      return false;
    }
    setState(() {
      isTesting = true;
    });

    final handler = Aihandler();
    handler.initDio();

    // 取列表第一个模型用于测试，若无则使用默认的回退模型
    String testModel = modelList.isNotEmpty ? modelList.first : modelName;
    if (testModel.isEmpty) testModel = 'gpt-3.5-turbo'; // 兜底防止报错

    await for (String token in handler.requestTest(
        _apiKeyController.text,
        testModel,
        _selectedProvider.defaultUrl.isEmpty
            ? _urlController.text
            : _selectedProvider.defaultUrl,
        _selectedProvider)) {
      if (token.isNotEmpty) {
        handler.interrupt();
        break;
      }
    }
    setState(() {
      isTesting = false;
    });

    return !handler.isError;
  }

  /// 弹窗：用于新增或修改模型名称
  void _showModelEditDialog({int? index, String? currentName}) {
    TextEditingController ctrl = TextEditingController(text: currentName ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? '添加模型' : '编辑模型'),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: '输入模型名称',
              helperText: index == null ? '支持逗号或换行分隔，批量添加' : '',
            ),
            autofocus: true,
            maxLines: index == null ? 3 : 1, // 新增时允许多行以支持批量
            minLines: 1,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                String val = ctrl.text.trim();
                if (val.isNotEmpty) {
                  setState(() {
                    if (index == null) {
                      // 批量添加逻辑：通过逗号、中文逗号或换行符分割
                      final newModels = val
                          .split(RegExp(r'[,\n，]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty);
                      for (var m in newModels) {
                        if (!modelList.contains(m)) {
                          modelList.add(m);
                        }
                      }
                    } else {
                      // 修改逻辑
                      modelList[index] = val;
                    }
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _saveApi();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.api == null ? '新建节点' : '编辑节点'),
          centerTitle: true,
          actions: widget.api != null
              ? [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制该节点',
                    onPressed: _duplicateApi,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '删除',
                    onPressed: () => _showDeleteConfirmDialog(context),
                  ),
                ]
              : null,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: [
              // --- 1. 基础信息区 ---
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: '节点显示名称',
                  hintText: '例如：OpenAI 官方、我的中转节点',
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入节点名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ServiceType>(
                value: _selectedProvider,
                decoration: InputDecoration(
                  labelText: '服务商类型',
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: ServiceType.values
                    .map((provider) => DropdownMenuItem(
                          value: provider,
                          child: Text(provider.toLocalString()),
                        ))
                    .toList(),
                onChanged: (ServiceType? value) {
                  if (value != null) {
                    setState(() {
                      _selectedProvider = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.w500),
                controller: _apiKeyController,
                obscureText: false,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 API Key';
                  }
                  return null;
                },
              ),
              if (_selectedProvider.defaultUrl.isEmpty) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: '自定义 URL',
                    hintText: '例如: https://api.openai.com/v1',
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入 URL';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),

              // --- 2. 模型列表管理区 ---
              Card(
                elevation: 0,
                color: colors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '可用模型列表 (${modelList.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              if (modelList.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      modelList.clear();
                                    });
                                  },
                                  child: const Text('清空'),
                                ),
                              TextButton.icon(
                                onPressed: () => _showModelEditDialog(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('添加'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      if (modelList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              '暂无模型，请手动添加或通过下方按钮获取',
                              style: TextStyle(color: colors.outline),
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: List.generate(modelList.length, (index) {
                            return InputChip(
                              label: Text(modelList[index]),
                              labelStyle: TextStyle(
                                  color: colors.onSecondaryContainer,
                                  fontSize: 13),
                              backgroundColor:
                                  colors.secondaryContainer.withOpacity(0.5),
                              deleteIconColor: colors.onSecondaryContainer,
                              onDeleted: () {
                                setState(() {
                                  modelList.removeAt(index);
                                });
                              },
                              onPressed: () {
                                _showModelEditDialog(
                                    index: index,
                                    currentName: modelList[index]);
                              },
                              tooltip: '点击编辑，右侧删除',
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- 3. 操作按钮区 ---
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.start,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: isFetchingModelList
                        ? null
                        : () async {
                            if (_apiKeyController.text.isEmpty) {
                              SillyChatApp.snackbarErr(context, '请先填写apiKey!');
                              return;
                            }
                            setState(() {
                              isFetchingModelList = true;
                            });
                            final list = await Servicehandlerfactory.getHandler(
                                    _selectedProvider,
                                    customURL: _urlController.text)
                                .fetchModelList(_apiKeyController.text);
                            if (list.isNotEmpty) {
                              SillyChatApp.snackbar(
                                  context, '获取成功，共${list.length}个模型');
                              setState(() {
                                // 替换并去重
                                modelList = list.toSet().toList();
                              });
                            } else {
                              SillyChatApp.snackbar(context, '获取失败或为空');
                            }
                            setState(() {
                              isFetchingModelList = false;
                            });
                          },
                    icon: isFetchingModelList
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('获取远端模型'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            if (_apiKeyController.text.isEmpty) {
                              SillyChatApp.snackbarErr(context, '请先填写apiKey!');
                              return;
                            }
                            isTestSuccess = await _sendTestMessage();
                            if (isTestSuccess!) {
                              SillyChatApp.snackbar(context, '测试成功!');
                            }
                          },
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (isTestSuccess == true
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 18)
                            : (isTestSuccess == false
                                ? const Icon(Icons.error,
                                    color: Colors.red, size: 18)
                                : const Icon(Icons.network_ping, size: 18))),
                    label: Text(
                      isTestSuccess == null
                          ? '测试连接'
                          : (isTestSuccess! ? '测试通过' : '连接失败'),
                      style: TextStyle(
                        color: isTestSuccess == true
                            ? Colors.green
                            : (isTestSuccess == false ? Colors.red : null),
                      ),
                    ),
                  ),
                  if (Servicehandlerfactory.getHandler(_selectedProvider)
                      .canFetchBalance)
                    OutlinedButton.icon(
                      onPressed: isFetchingBalance
                          ? null
                          : () async {
                              if (_apiKeyController.text.isEmpty) {
                                SillyChatApp.snackbarErr(
                                    context, '请先填写apiKey!');
                                return;
                              }
                              setState(() {
                                isFetchingBalance = true;
                              });
                              final res =
                                  await Servicehandlerfactory.getHandler(
                                          _selectedProvider,
                                          customURL: _urlController.text)
                                      .fetchBalance(_apiKeyController.text);

                              setState(() {
                                balanceResult = res;
                                isFetchingBalance = false;
                              });
                            },
                      icon: isFetchingBalance
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.account_balance_wallet_outlined,
                              size: 18),
                      label: const Text('查询余额'),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // --- 4. 余额结果区 ---
              if (balanceResult != null) ...[
                Card(
                  color: colors.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: colors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              '余额查询结果',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        MarkdownBody(
                          data: balanceResult ?? '',
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- 5. 高级设置区 ---
              ExpansionTile(
                title: const Text('高级请求设置'),
                initiallyExpanded: _isPanelExpanded,
                collapsedBackgroundColor: colors.surfaceContainerLowest,
                backgroundColor: colors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isPanelExpanded = expanded;
                  });
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _remarksController,
                          decoration: InputDecoration(
                            labelText: '备注 (选填)',
                            filled: true,
                            fillColor: colors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _requestBodyController,
                          decoration: InputDecoration(
                            labelText: '附加请求体 JSON (选填)',
                            hintText:
                                '例如: {"chat_template_kwargs": {"thinking": True}}',
                            helperText: '发送API请求时将合并到Body中，支持Python风格语法',
                            filled: true,
                            fillColor: colors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60), // 底部留白
            ],
          ),
        ),
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
      modelName: modelList.isNotEmpty ? modelList.first : modelName,
      url: _selectedProvider.defaultUrl.isEmpty
          ? _urlController.text
          : _selectedProvider.defaultUrl,
      provider: _selectedProvider,
      remarks: _remarksController.text,
      requestBody: _requestBodyController.text.isNotEmpty
          ? _requestBodyController.text
          : null,
      models: List.from(modelList), // 一并复制所有模型
    );

    await controller.addApi(newApi);
    Get.back();
  }
}
