import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
// 请确保导入了你的 ApiModel 和 ServiceType
// import 'your_path/api_model.dart';

/// 用于页面返回结果的结构
class ModelSelectionResult {
  final ApiModel api;
  final ServiceType provider;
  final String modelName;

  ModelSelectionResult({
    required this.api,
    required this.provider,
    required this.modelName,
  });
}

class ApiModelSelectionPage extends StatefulWidget {
  final List<ApiModel> apiList;

  const ApiModelSelectionPage({super.key, required this.apiList});

  @override
  State<ApiModelSelectionPage> createState() => _ApiModelSelectionPageState();
}

class _ApiModelSelectionPageState extends State<ApiModelSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ApiModel> _filteredApiList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredApiList = widget.apiList;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredApiList = widget.apiList;
      } else {
        _filteredApiList = widget.apiList.where((api) {
          // 匹配节点名、服务商名，或者该节点下包含符合要求的模型
          final matchName =
              api.displayName.toLowerCase().contains(_searchQuery);
          final matchProvider =
              api.provider.name.toLowerCase().contains(_searchQuery);
          final matchAnyModel = _getUniqueModels(api)
              .any((m) => m.toLowerCase().contains(_searchQuery));

          return matchName || matchProvider || matchAnyModel;
        }).toList();
      }
    });
  }

  /// 获取去重后的模型列表（合并默认模型和备选模型数组）
  List<String> _getUniqueModels(ApiModel api) {
    final Set<String> models = {
      if (api.modelName.isNotEmpty) api.modelName,
      ...api.models,
    };
    return models.toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text("选择模型"),
        centerTitle: true,
        scrolledUnderElevation: 0, // 滚动时保持纯净背景
      ),
      body: Column(
        children: [
          // --- 搜索栏 ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SearchBar(
              controller: _searchController,
              hintText: '搜索节点或模型...',
              leading: Icon(Icons.search, color: colors.onSurfaceVariant),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
              ],
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor:
                  WidgetStatePropertyAll(colors.surfaceContainerHigh),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // --- 列表区域 ---
          Expanded(
            child: _filteredApiList.isEmpty
                ? Center(
                    child: Text(
                      "未找到匹配的节点或模型",
                      style: TextStyle(color: colors.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: _filteredApiList.length,
                    itemBuilder: (context, index) {
                      final api = _filteredApiList[index];
                      return _buildApiCard(api, colors, context);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建单个 API 节点的分组卡片
  Widget _buildApiCard(ApiModel api, ColorScheme colors, BuildContext context) {
    // 获取该节点下所有的模型（包含搜索过滤）
    List<String> displayModels = _getUniqueModels(api);
    if (_searchQuery.isNotEmpty) {
      displayModels = displayModels
          .where((m) => m.toLowerCase().contains(_searchQuery))
          .toList();
      // 如果只有节点名匹配，但模型名不匹配，则展示所有模型
      if (displayModels.isEmpty &&
          (api.displayName.toLowerCase().contains(_searchQuery) ||
              api.provider.name.toLowerCase().contains(_searchQuery))) {
        displayModels = _getUniqueModels(api);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: colors.outlineVariant.withOpacity(0.5), width: 1),
      ),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 头部：服务商 + 节点名称 ---
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    api.provider.toLocalString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    api.displayName.isNotEmpty ? api.displayName : '未命名节点',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),

            // --- 底部：可点击的模型流式标签 (Chips) ---
            if (displayModels.isEmpty)
              Text(
                "暂无可用模型",
                style: TextStyle(fontSize: 14, color: colors.outline),
              )
            else
              Wrap(
                spacing: 8.0, // 标签之间的水平间距
                runSpacing: 8.0, // 标签之间的垂直间距
                children: displayModels.map((modelName) {
                  return ActionChip(
                    avatar: Icon(Icons.smart_toy_outlined,
                        size: 16, color: colors.primary),
                    label: Text(modelName),
                    labelStyle: TextStyle(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: colors.secondaryContainer.withOpacity(0.5),
                    side: BorderSide(color: colors.secondaryContainer),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onPressed: () {
                      // 点击即选中，带着结果返回上一页
                      final result = ModelSelectionResult(
                        api: api,
                        provider: api.provider,
                        modelName: modelName,
                      );
                      Navigator.of(context).pop(result);
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
