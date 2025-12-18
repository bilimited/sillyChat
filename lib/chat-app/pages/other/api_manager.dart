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
            return Obx(()=>Card(
              
              shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: VaultSettingController.of().defaultApi.value == api.id
            ? BorderSide(width: 2, color: colors.primary)
            : BorderSide.none,
      ),
              child: InkWell(
                onTap: () =>
                    customNavigate(ApiEditPage(api: api), context: context),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 左侧文本信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '${api.displayName}',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                ],
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
                      
                      // --- 新增：模拟单选按钮 ---
                      Obx(() {
                        final isDefault =
                            controller.defaultApi.value == api.id;
                        return IconButton(
                          onPressed: () {
                            if (!isDefault) {
                              controller.defaultApi.value = api.id;
                              controller.saveSettings();
                            }
                          },
                          icon: Icon(
                            isDefault
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isDefault
                                ? colors.primary
                                : colors.outline, // 选中用主色，未选中用轮廓色
                          ),
                          tooltip: '设为默认',
                        );
                      }),

                      // 右侧更多菜单（保留了删除功能，也可以保留设为默认作为双重入口）
                      PopupMenuButton<String>(
                        onSelected: (value) {
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
            ),key: ValueKey(api.id),) ;
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