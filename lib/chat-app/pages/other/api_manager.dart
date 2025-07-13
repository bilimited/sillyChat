import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'api_edit.dart';

class ApiManagerPage extends StatelessWidget {
  final VaultSettingController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            return ListTile(
              key: ValueKey(api),
              title: Text('${api.displayName}(${api.modelName})'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('URL: ${api.url}'),
                  if (api.remarks != null) Text('备注: ${api.remarks}'),
                ],
              ),
              onTap: () => customNavigate (ApiEditPage(api: api),context: context),
              trailing: const Icon(Icons.drag_handle),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => customNavigate (ApiEditPage(), context: context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
