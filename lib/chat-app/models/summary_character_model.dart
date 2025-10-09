import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';

class SummaryCharacterModel extends CharacterModel {
  SummaryCharacterModel(
      {required super.id,
      required super.remark,
      required super.roleName,
      required super.avatar,
      required super.category});

  @override
  ChatOptionModel? get bindOption =>
      VaultSettingController.of().summarySetting.value.summaryOption;
}
