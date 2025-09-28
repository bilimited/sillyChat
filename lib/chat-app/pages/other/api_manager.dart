import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'api_edit.dart';

class ApiManagerPage extends StatelessWidget {
  final VaultSettingController controller = Get.find();
  final GlobalKey<ScaffoldState>? scaffoldKey;

  ApiManagerPage({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              scaffoldKey?.currentState?.openDrawer();
            },
            icon: Icon(Icons.menu)),
        title: Text("API"),
      ),
      body: Obx(
        () => ReorderableListView.builder(
          itemCount: controller.apis.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            final api = controller.apis.removeAt(oldIndex);
            controller.apis.insert(newIndex, api);
            controller.saveSettings();
          },
          itemBuilder: (context, index) {
            final api = controller.apis[index];
            return Card(
              key: ValueKey(api.id),
              child: InkWell(
                onTap: () =>
                    customNavigate(ApiEditPage(api: api), context: context),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 使用Expanded来让Column占据所有可用空间，从而将按钮推到末尾
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(
                              () => Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '${api.displayName}',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  if (VaultSettingController.of()
                                          .defaultApi
                                          .value ==
                                      api.id)
                                    Card(
                                      color: colors.secondaryContainer,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 6),
                                        child: Text(
                                          '默认',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            ),
                            Text(
                              '${api.modelName}',
                              style: TextStyle(
                                  fontSize: 16, color: colors.outline),
                            ),
                            if (api.remarks != null && api.remarks!.isNotEmpty)
                              Text(
                                '备注: ${api.remarks}',
                                style: TextStyle(
                                    fontSize: 14, color: colors.outline),
                              ),
                          ],
                        ),
                      ),
                      // 这是新添加的弹出菜单按钮
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          // 这里处理点击事件，'value'就是PopupMenuItem的value属性
                          if (value == 'set_default') {
                            VaultSettingController.of().defaultApi.value =
                                api.id;
                            VaultSettingController.of().saveSettings();
                          } else if (value == 'delete') {
                            VaultSettingController.of().deleteApi(id: api.id);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'set_default',
                            child: Text('设为默认'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('删除'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => customNavigate(ApiEditPage(), context: context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
