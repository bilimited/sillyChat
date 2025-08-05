import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/widgets/other/regex_list_editor.dart';
import 'package:get/get.dart';

class EditGlobalRegexPage extends StatefulWidget {
  EditGlobalRegexPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _EditGlobalRegexPageState();
  }
}

class _EditGlobalRegexPageState extends State<EditGlobalRegexPage> {
  VaultSettingController get settingController =>
      Get.find<VaultSettingController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑全局正则'),
      ),
      body: Center(
          child: 
              Column(
        children: [
          Obx(() => Expanded(child: RegexListEditor(
                // 傻逼GetX
                // ignore: invalid_use_of_protected_member
                regexList: settingController.regexes.value,
                onChanged: (reg) {
                  settingController.regexes.value = reg;
                  settingController.saveSettings();
                },
              )),
          
          ) ,
          SizedBox(height: 32,)
        ],
      )),
    );
  }
}
