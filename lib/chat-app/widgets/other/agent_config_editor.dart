import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/agent_config_model.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';

class AgentConfigEditor extends StatefulWidget {
  final AgentConfig? config;
  final ValueChanged<AgentConfig> onChanged;

  const AgentConfigEditor({
    Key? key,
    required this.config,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<AgentConfigEditor> createState() => _AgentConfigEditorState();
}

class _AgentConfigEditorState extends State<AgentConfigEditor> {
  late bool _enabled;
  late int _maxCallRounds;
  late Set<String> _selectedTools;

  List<String> get _allTools =>
      ToolRegistry.instance.definitions.map((d) => d.function.name).toList();

  bool get _isAllSelected {
    if (_allTools.isEmpty) return true;
    return _selectedTools.containsAll(_allTools);
  }

  @override
  void initState() {
    super.initState();
    _syncFromConfig();
  }

  @override
  void didUpdateWidget(covariant AgentConfigEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _syncFromConfig();
    }
  }

  void _syncFromConfig() {
    _enabled = widget.config?.enabled ?? false;
    _maxCallRounds = widget.config?.maxCallRounds ?? 5;
    final whitelist = widget.config?.toolWhitelist;
    _selectedTools = (whitelist != null && whitelist.isNotEmpty)
        ? whitelist.toSet()
        : _allTools.toSet();
  }

  void _emit() {
    widget.onChanged(AgentConfig(
      enabled: _enabled,
      toolWhitelist:
          _isAllSelected ? null : _selectedTools.toList(),
      maxCallRounds: _maxCallRounds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final allTools = _allTools;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 启用开关 ──
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用 Agent 模式'),
            subtitle: const Text('允许 AI 调用工具执行操作'),
            value: _enabled,
            onChanged: (val) {
              setState(() => _enabled = val);
              _emit();
            },
          ),
          const Divider(),

          // ── 配置区域（仅在启用时显示）──
          if (_enabled) ...[
            const SizedBox(height: 8),

            // 最大调用轮数
            _buildMaxRoundsSection(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 工具白名单
            _buildToolWhitelistSection(allTools),
          ],
        ],
      ),
    );
  }

  Widget _buildMaxRoundsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最大调用轮数',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '每次对话中 Agent 最多进行 $_maxCallRounds 轮工具调用，防止无限循环',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('1'),
                Expanded(
                  child: Slider(
                    value: _maxCallRounds.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_maxCallRounds',
                    onChanged: (val) {
                      setState(() => _maxCallRounds = val.round());
                    },
                    onChangeEnd: (_) => _emit(),
                  ),
                ),
                const Text('20'),
                SizedBox(
                  width: 56,
                  child: Text(
                    '$_maxCallRounds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolWhitelistSection(List<String> allTools) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '工具白名单',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_isAllSelected) {
                        _selectedTools.clear();
                      } else {
                        _selectedTools = allTools.toSet();
                      }
                    });
                    _emit();
                  },
                  child: Text(_isAllSelected ? '全部取消' : '全选'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _selectedTools.isEmpty
                  ? '未选择任何工具'
                  : _isAllSelected
                      ? '已选择全部 ${allTools.length} 个工具'
                      : '已选择 ${_selectedTools.length}/${allTools.length} 个工具',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            if (allTools.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '暂无已注册的工具。请确保 ToolRegistry 已初始化。',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...allTools.map((toolName) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      toolName,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    value: _selectedTools.contains(toolName),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedTools.add(toolName);
                        } else {
                          _selectedTools.remove(toolName);
                        }
                      });
                      _emit();
                    },
                  )),
          ],
        ),
      ),
    );
  }
}
