import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/regex_model.dart';

class RegexEditScreen extends StatefulWidget {
  final RegexModel? regexModel; // 传入要编辑的RegexModel，如果是新增则为null

  const RegexEditScreen({Key? key, this.regexModel}) : super(key: key);

  @override
  State<RegexEditScreen> createState() => _RegexEditScreenState();
}

class _RegexEditScreenState extends State<RegexEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late RegexModel _currentRegexModel;

  // Use RangeValues to store the min and max depth for the slider
  late RangeValues _depthRangeValues;

  String testText = '';

  @override
  void initState() {
    super.initState();
    // 如果传入了regexModel，则使用其值初始化；否则创建一个新的默认模型
    _currentRegexModel = widget.regexModel?.copyWith() ??
        RegexModel(
          id: DateTime.now().millisecondsSinceEpoch, // 示例ID生成
          name: '',
          pattern: '',
          replacement: '',
        );

    // Initialize depthRangeValues from _currentRegexModel
    _depthRangeValues = RangeValues(
      _currentRegexModel.depthMin.toDouble() == -1
          ? 0.0 // Default min for slider if -1 (infinite)
          : _currentRegexModel.depthMin.toDouble(),
      _currentRegexModel.depthMax.toDouble() == -1
          ? 10.0 // Default max for slider if -1 (infinite), adjust as needed
          : _currentRegexModel.depthMax.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define a maximum value for your slider. Adjust this based on your needs.
    // For example, if depth can realistically go up to 10 or 20.
    const double maxDepthSliderValue = 10.0; // Example max depth for slider

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.regexModel == null ? '新建正则表达式' : '编辑正则表达式',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveForm,
        label: const Text('保存正则'),
        icon: const Icon(Icons.save),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSectionTitle('基本信息'),
              TextFormField(
                initialValue: _currentRegexModel.name,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '输入正则表达式的名称',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入名称';
                  }
                  return null;
                },
                onSaved: (value) {
                  _currentRegexModel = _currentRegexModel.copyWith(name: value);
                },
              ),
              const SizedBox(height: 15.0),
              TextFormField(
                initialValue: _currentRegexModel.pattern,
                decoration: const InputDecoration(
                  labelText: '正则表达式',
                  hintText: '输入正则表达式模式',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.pattern),
                ),
                minLines: 1,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入正则表达式';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _currentRegexModel =
                        _currentRegexModel.copyWith(pattern: value);
                  });
                },
              ),
              const SizedBox(height: 15.0),
              TextFormField(
                initialValue: _currentRegexModel.replacement,
                decoration: const InputDecoration(
                  labelText: '替换文本',
                  hintText: '输入替换的文本',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.text_fields),
                ),
                minLines: 1,
                maxLines: 5,
                onChanged: (value) {
                  setState(() {
                    _currentRegexModel =
                        _currentRegexModel.copyWith(replacement: value);
                  });
                },
              ),
              const SizedBox(height: 15.0),
              TextFormField(
                initialValue: _currentRegexModel.trim,
                decoration: const InputDecoration(
                  labelText: '修剪文本 (可选)',
                  hintText: '输入正则匹配前需要删除的文本，用换行隔开',
                  prefixIcon: Icon(Icons.content_cut),
                ),
                minLines: 1,
                maxLines: 5,
                onChanged: (value) {
                  setState(() {
                    _currentRegexModel =
                        _currentRegexModel.copyWith(trim: value);
                  });
                },
              ),
              const SizedBox(height: 15.0),
              CheckboxListTile(
                title: const Text('启用此规则',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('开启或关闭此正则表达式规则'),
                value: _currentRegexModel.enabled,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _currentRegexModel =
                          _currentRegexModel.copyWith(enabled: value);
                    });
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 20, thickness: 1),
              _buildSectionTitle('应用时机'),
              CheckboxListTile(
                dense: true,
                title: const Text('在渲染时应用',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('在消息显示前进行处理'),
                value: _currentRegexModel.onRender,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _currentRegexModel =
                          _currentRegexModel.copyWith(onRender: value);
                    });
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('在发送请求时应用',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('在用户消息发送到AI前进行处理'),
                value: _currentRegexModel.onRequest,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _currentRegexModel =
                          _currentRegexModel.copyWith(onRequest: value);
                    });
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('在收到响应时应用',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('在AI响应到达后进行处理'),
                value: _currentRegexModel.onResponse,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _currentRegexModel =
                          _currentRegexModel.copyWith(onResponse: value);
                    });
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 20, thickness: 1),
              _buildSectionTitle('作用域'),
              CheckboxListTile(
                title: const Text('应用于用户消息',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('此规则应用于用户发送的消息'),
                value: _currentRegexModel.scopeUser,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _currentRegexModel =
                          _currentRegexModel.copyWith(scopeUser: value);
                    });
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('应用于AI消息',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('此规则应用于AI生成的消息'),
                value: _currentRegexModel.scopeAssistant,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _currentRegexModel =
                          _currentRegexModel.copyWith(scopeAssistant: value);
                    });
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 20, thickness: 1),
              _buildSectionTitle('深度范围'),
              // Display current range values
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '当前深度范围: ${_depthRangeValues.start.toInt() == 0 ? '0' : _depthRangeValues.start.toInt() == -1 ? '无限' : _depthRangeValues.start.toInt()} - ${_depthRangeValues.end.toInt() == maxDepthSliderValue.toInt() ? '无限' : _depthRangeValues.end.toInt() == -1 ? '无限' : _depthRangeValues.end.toInt()}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              RangeSlider(
                values: _depthRangeValues,
                min: 0.0, // Minimum depth (can be 0 or -1 for infinite)
                max:
                    maxDepthSliderValue, // Maximum depth you want to allow on the slider
                divisions:
                    maxDepthSliderValue.toInt(), // Number of discrete intervals
                labels: RangeLabels(
                  _depthRangeValues.start.toInt() == 0
                      ? '0'
                      : (_depthRangeValues.start.toInt() == -1
                          ? '无限'
                          : _depthRangeValues.start.toInt().toString()),
                  _depthRangeValues.end.toInt() == maxDepthSliderValue.toInt()
                      ? '无限'
                      : (_depthRangeValues.end.toInt() == -1
                          ? '无限'
                          : _depthRangeValues.end.toInt().toString()),
                ),
                onChanged: (RangeValues values) {
                  setState(() {
                    _depthRangeValues = values;
                  });
                },
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
              const Divider(height: 20, thickness: 1),
              _buildSectionTitle('测试'),
              const SizedBox(
                height: 10,
              ),
              TextFormField(
                maxLines: 5,
                initialValue: testText,
                onChanged: (value) {
                  setState(() {
                    testText = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: '测试文本',
                  hintText: '输入测试文本',
                  prefixIcon: Icon(Icons.bug_report),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text('替换结果: ' + _currentRegexModel.process(testText)),
              const SizedBox(height: 64.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10.0, 0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Update _currentRegexModel with the values from the RangeSlider
      _currentRegexModel = _currentRegexModel.copyWith(
        depthMin: _depthRangeValues.start.toInt() == 0 &&
                widget.regexModel?.depthMin == -1
            ? -1 // Preserve -1 if it was originally -1 and slider is at 0
            : _depthRangeValues.start.toInt(),
        depthMax: _depthRangeValues.end.toInt() == 10 &&
                widget.regexModel?.depthMax == -1
            ? -1 // Preserve -1 if it was originally -1 and slider is at max
            : _depthRangeValues.end.toInt(),
      );

      // Handle the "无限" (infinite) logic for -1 values
      // If the slider is at its min (0) or max (10) and the original value was -1, keep it -1.
      // Otherwise, use the slider's integer value.
      if (_depthRangeValues.start.toInt() == 0 &&
          widget.regexModel?.depthMin == -1) {
        _currentRegexModel = _currentRegexModel.copyWith(depthMin: -1);
      } else {
        _currentRegexModel = _currentRegexModel.copyWith(
            depthMin: _depthRangeValues.start.toInt());
      }

      const double maxDepthSliderValue = 10.0;
      if (_depthRangeValues.end.toInt() == maxDepthSliderValue.toInt() &&
          widget.regexModel?.depthMax == -1) {
        _currentRegexModel = _currentRegexModel.copyWith(depthMax: -1);
      } else {
        _currentRegexModel = _currentRegexModel.copyWith(
            depthMax: _depthRangeValues.end.toInt());
      }

      // Return the updated model
      Navigator.of(context).pop(_currentRegexModel);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
