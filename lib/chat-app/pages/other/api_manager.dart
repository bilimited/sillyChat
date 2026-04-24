import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart' show ApiModel;
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'api_edit.dart';

// 注意：请确保导入了你的 ApiModel 和 ServiceType 的定义文件

class ApiManagerPage extends StatelessWidget {
  final VaultSettingController controller = Get.find();
  final GlobalKey<ScaffoldState>? scaffoldKey;

  ApiManagerPage({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("API 管理"),
        centerTitle: true,
      ),
      // 使用 Obx 监听整个列表的变化（包括增删排序）
      body: Obx(
        () {
          if (controller.apis.isEmpty) {
            return Center(
              child: Text(
                "暂无 API 节点，请点击下方添加",
                style: TextStyle(color: colors.outline),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 100, top: 8), // 底部留白给 FAB
            itemCount: controller.apis.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final api = controller.apis.removeAt(oldIndex);
              controller.apis.insert(newIndex, api);
              controller.saveSettings();
            },
            itemBuilder: (context, index) {
              final api = controller.apis[index];
              return _ApiCard(
                key: ValueKey(api.id), // ReorderableListView 必须有唯一的 key
                api: api,
                controller: controller,
                colors: colors,
                index: index,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => customNavigate(ApiEditPage(), context: context),
        icon: const Icon(Icons.add),
        label: const Text("新建 API"),
      ),
    );
  }
}

/// 独立的卡片组件，使主逻辑更清晰
class _ApiCard extends StatelessWidget {
  final ApiModel api;
  final VaultSettingController controller;
  final ColorScheme colors;
  final int index;

  const _ApiCard({
    super.key,
    required this.api,
    required this.controller,
    required this.colors,
    required this.index,
  });

  // API Key 脱敏处理工具函数
  String _maskApiKey(String key) {
    if (key.isEmpty) return '未设置';
    if (key.length <= 10) return '********';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    // 监听单个卡片的选中状态变化
    return Obx(() {
      final isDefault = controller.defaultApiId.value == api.id;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: isDefault ? 2 : 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isDefault
                ? BorderSide(color: colors.primary, width: 2)
                : BorderSide(color: colors.outlineVariant, width: 1),
          ),
          color: isDefault
              ? colors.primaryContainer.withOpacity(0.3)
              : colors.surfaceContainerLow,
          child: InkWell(
            onTap: () =>
                customNavigate(ApiEditPage(api: api), context: context),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 头部：服务商 Badge + 名称 + 右侧菜单 ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 服务商标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                      // 显示名称
                      Expanded(
                        child: Text(
                          api.displayName.isNotEmpty
                              ? api.displayName
                              : '未命名节点',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 默认标识
                      if (isDefault)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.check_circle,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                      // 更多操作菜单
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: colors.onSurfaceVariant),
                        onSelected: (value) {
                          if (value == 'set_default') {
                            controller.defaultApiId.value = api.id;
                            controller.saveSettings();
                          } else if (value == 'delete') {
                            controller.deleteApi(id: api.id);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          if (!isDefault)
                            PopupMenuItem<String>(
                              value: 'set_default',
                              child: Row(
                                children: [
                                  Icon(Icons.check, color: colors.primary),
                                  const SizedBox(width: 8),
                                  const Text('设为默认'),
                                ],
                              ),
                            ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: colors.error),
                                const SizedBox(width: 8),
                                Text('删除',
                                    style: TextStyle(color: colors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- 主体信息区：模型、URL、API Key ---
                  _buildInfoRow(Icons.smart_toy_outlined, api.modelName),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.link_rounded, api.url),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.key_outlined, _maskApiKey(api.apiKey)),

                  // // --- 底部区：备注（如果有）和 拖拽手柄 ---
                  // const SizedBox(height: 12),
                  // Row(
                  //   crossAxisAlignment: CrossAxisAlignment.end,
                  //   children: [
                  //     Expanded(
                  //       child: api.remarks != null && api.remarks!.isNotEmpty
                  //           ? Container(
                  //               padding: const EdgeInsets.symmetric(
                  //                   horizontal: 10, vertical: 8),
                  //               decoration: BoxDecoration(
                  //                 color: colors.surfaceContainerHighest,
                  //                 borderRadius: BorderRadius.circular(8),
                  //               ),
                  //               child: Text(
                  //                 '备注: ${api.remarks}',
                  //                 style: TextStyle(
                  //                   fontSize: 13,
                  //                   color: colors.onSurfaceVariant,
                  //                 ),
                  //                 maxLines: 2,
                  //                 overflow: TextOverflow.ellipsis,
                  //               ),
                  //             )
                  //           : const SizedBox.shrink(),
                  //     ),
                  //     // 拖拽暗示图标（放在右下角）
                  //     Tooltip(
                  //       message: '长按拖动排序',
                  //       child: Icon(
                  //         Icons.drag_handle,
                  //         color: colors.outlineVariant,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  /// 构建带图标的信息行工具组件
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
