import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandlerFactory.dart';
import 'package:flutter_example/chat-app/widgets/option_input.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
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

  String modelName = "";

  late TextEditingController _apiKeyController;
  //late TextEditingController _modelNameController;
  late TextEditingController _urlController;
  late TextEditingController _remarksController;
  late TextEditingController _displayNameController;
  late TextEditingController _requestBodyController;
  late ServiceProvider _selectedProvider;

  bool _isPanelExpanded = false;
  bool isFetchingModelList = false;
  bool isTesting = false;
  bool? isTestSuccess = null; // null 代表未测试

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.api?.apiKey ?? '');
    modelName = widget.api?.modelName ?? '';
    _urlController = TextEditingController(text: widget.api?.url ?? '');
    _remarksController = TextEditingController(text: widget.api?.remarks ?? '');
    _displayNameController =
        TextEditingController(text: widget.api?.displayName ?? '');
    _requestBodyController =
        TextEditingController(text: widget.api?.requestBody ?? '');

    _selectedProvider = widget.api?.provider ?? ServiceProvider.openai;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    // _modelNameController.dispose();
    _urlController.dispose();
    _remarksController.dispose();
    _displayNameController.dispose();
    _requestBodyController.dispose();
    super.dispose();
  }

  void _saveApi() async {
    if (_formKey.currentState!.validate()) {
      final api = ApiModel(
        id: widget.api?.id ?? DateTime.now().millisecondsSinceEpoch,
        apiKey: _apiKeyController.text,
        displayName: _displayNameController.text,
        modelName: modelName,
        url: _selectedProvider.defaultUrl.isEmpty
            ? _urlController.text
            : _selectedProvider.defaultUrl,
        provider: _selectedProvider,
        remarks: _remarksController.text,
        requestBody: _requestBodyController.text.isNotEmpty
            ? _requestBodyController.text
            : null,
      );

      if (widget.api == null) {
        await controller.addApi(api);
      } else {
        await controller.updateApi(api);
      }

      Get.back(result: api);
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
    await for (String token in handler.requestTest(
        _apiKeyController.text,
        modelName,
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

  List<String> get modelList {
    if (SettingController.cachedModelList[_selectedProvider] != null) {
      return SettingController.cachedModelList[_selectedProvider]!;
    }
    return _selectedProvider.modelList;
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
              ),
              items: ServiceProvider.values
                  .map((provider) => DropdownMenuItem(
                        value: provider,
                        child: Text(provider.toLocalString()),
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
              style: TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold),
              controller: _apiKeyController,
              obscureText: false,
              decoration: const InputDecoration(
                labelText: 'API Key',
                // suffixIcon: Icon(Icons.visibility_off),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Obx(() => CustomOptionInputWidget.fromStringOptions(
                  options: modelList,
                  labelText: "模型名称",
                  initialValue: modelName,
                  onChanged: (value) {
                    final oldval = modelName;
                    modelName = value;
                    if (_displayNameController.text.isEmpty ||
                        _displayNameController.text == oldval) {
                      _displayNameController.text = value;
                    }
                  },
                )),
            const SizedBox(height: 16),
            if (_selectedProvider.defaultUrl.isEmpty)
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL(格式如:https://api.openai.com/v1)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 URL';
                  }
                  return null;
                },
              ),
            Row(
              children: [
                if (widget.api != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () {
                        VaultSettingController.of().defaultApi.value =
                            widget.api!.id;
                        VaultSettingController.of().saveSettings();
                        SillyChatApp.snackbar(context, '设置成功!');
                      },
                      child: Text('设为默认API')),
                ],
                const SizedBox(height: 16),
                isFetchingModelList
                    ? ElevatedButton.icon(
                        onPressed: null,
                        icon: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: Text('正在获取...'),
                      )
                    : TextButton(
                        onPressed: () async {
                          if (_apiKeyController.text.isEmpty) {
                            SillyChatApp.snackbarErr(context, '请先填写apiKey!');
                            return;
                          }
                          setState(() {
                            isFetchingModelList = true;
                          });
                          final list = await Servicehandlerfactory.getHandler(
                                  _selectedProvider)
                              .fetchModelList(_apiKeyController.text);
                          if (list.isNotEmpty) {
                            SillyChatApp.snackbar(
                                context, '获取成功，共${list.length}个模型');
                            SettingController
                                .cachedModelList[_selectedProvider] = list;
                            SettingController.cachedModelList.refresh();
                            SettingController.of.saveGlobalSettings();
                          } else {
                            SillyChatApp.snackbar(context, '获取失败');
                          }
                          setState(() {
                            isFetchingModelList = false;
                          });
                        },
                        child: Text('获取模型列表'),
                      ),
                const SizedBox(height: 16),
                isTesting
                    ? ElevatedButton.icon(
                        onPressed: null,
                        icon: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: Text('正在等待响应...'),
                      )
                    : TextButton(
                        onPressed: () async {
                          if (_apiKeyController.text.isEmpty) {
                            SillyChatApp.snackbarErr(context, '请先填写apiKey!');
                            return;
                          }
                          isTestSuccess = await _sendTestMessage();
                          if (isTestSuccess!) {
                            SillyChatApp.snackbar(context, '测试成功!');
                          } else {}
                        },
                        child: isTestSuccess == null
                            ? Text('发送测试消息')
                            : isTestSuccess!
                                ? Text(
                                    '测试成功！',
                                    style: TextStyle(color: Colors.green),
                                  )
                                : Text('连接失败...',
                                    style: TextStyle(color: Colors.red)),
                      ),
              ],
            ),
            SizedBox(
              height: 32,
            ),
            ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  _isPanelExpanded = !_isPanelExpanded;
                });
              },
              children: [
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return ListTile(
                      title: Text('高级设置'),
                    );
                  },
                  isExpanded: _isPanelExpanded,
                  body: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: '显示名称(选填)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _remarksController,
                          decoration: const InputDecoration(
                            labelText: '备注(选填)',
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        TextFormField(
                          controller: _requestBodyController,
                          decoration: const InputDecoration(
                            labelText: '请求附加内容(选填)',
                            hintText:
                                '在发送API请求时附加的内容，支持JSON格式或Python风格语法\n例如: {"chat_template_kwargs": {"thinking": True}}',
                            helperText:
                                '支持Python风格的True/False/None，会自动转换为JSON格式',
                          ),
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ElevatedButton.icon(
            //     onPressed: () {
            //       Aihandler.testConnectivity(
            //           _urlController.text
            //               .replaceAll('/v1/chat/completions', '')
            //               .replaceAll('/chat/completions', ''),
            //           (isSuccess, message) {
            //         Get.snackbar(isSuccess ? '成功' : '失败', message,
            //             snackPosition: SnackPosition.BOTTOM,
            //             colorText: isSuccess ? Colors.green : Colors.red);
            //       });
            //     },
            //     label: Text('测试连通性'))
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
      modelName: modelName,
      url: _selectedProvider.defaultUrl.isEmpty
          ? _urlController.text
          : _selectedProvider.defaultUrl,
      provider: _selectedProvider,
      remarks: _remarksController.text,
      requestBody: _requestBodyController.text.isNotEmpty
          ? _requestBodyController.text
          : null,
    );

    await controller.addApi(newApi);
    Get.back();
  }
}
