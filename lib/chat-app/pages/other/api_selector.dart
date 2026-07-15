import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/pages/other/api_edit.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';

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
        title: const Text("选择模型",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: '搜索节点或模型...',
                  hintStyle: TextStyle(fontSize: 14, color: colors.outline),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filteredApiList.isEmpty
          ? Center(
              child: Text("未找到相关模型", style: TextStyle(color: colors.outline)))
          : ListView.builder(
              itemCount: _filteredApiList.length,
              itemBuilder: (context, index) {
                return _buildCollapsibleSection(
                    _filteredApiList[index], colors);
              },
            ),
    );
  }

  /// 构建可折叠的节点分组
  Widget _buildCollapsibleSection(ApiModel api, ColorScheme colors) {
    List<String> displayModels = _getUniqueModels(api);
    if (_searchQuery.isNotEmpty) {
      displayModels = displayModels
          .where((m) => m.toLowerCase().contains(_searchQuery))
          .toList();
      // 如果搜索的是节点名但没搜到具体模型，则展示该节点下所有模型
      if (displayModels.isEmpty &&
          (api.displayName.toLowerCase().contains(_searchQuery) ||
              api.provider.name.toLowerCase().contains(_searchQuery))) {
        displayModels = _getUniqueModels(api);
      }
    }

    return Theme(
      // 去除 ExpansionTile 展开时的上下分割线
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(api.displayName), // 保持折叠状态
        initiallyExpanded: true, // 默认展开
        backgroundColor: colors.surface,
        collapsedBackgroundColor: colors.surface,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        visualDensity: VisualDensity.compact,
        // --- 标题部分 ---
        title: Row(
          children: [
            GestureDetector(
              onTap: () async {
                await customNavigate(ApiEditPage(api: api), context: context);
                setState(() {});
              },
              child: Expanded(
                child: Text(
                  api.displayName.isNotEmpty ? api.displayName : '未命名节点',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        // --- 子项（模型列表） ---
        children: [
          if (displayModels.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("无匹配模型", style: TextStyle(fontSize: 13)),
            )
          else
            ...displayModels
                .map((modelName) => _buildModelItem(api, modelName, colors)),
          // 下方加一个细微的底部分割线，区分不同分组
          Divider(height: 1, color: colors.outlineVariant.withOpacity(0.3)),
        ],
      ),
    );
  }

  /// 构建模型行项
  Widget _buildModelItem(ApiModel api, String modelName, ColorScheme colors) {
    return InkWell(
      onTap: () {
        final result = ModelSelectionResult(
          api: api,
          provider: api.provider,
          modelName: modelName,
        );
        Navigator.of(context).pop(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: colors.outlineVariant.withOpacity(0.2), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                modelName,
                style: TextStyle(fontSize: 15, color: colors.onSurface),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: colors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
