import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/prompt_controller.dart';
import 'package:get/get.dart';

void MigrationStart(){
  // CharacterController characterController = Get.find();
  // PromptController promptController = Get.find();
  // Get.snackbar("错误", '迁移方法MigrationStart()已弃用');
  
  // // 获取用于生成存档的Prompt模板
  // final archivePrompt = promptController.getPromptByNameAndRole("角色介绍", "system");
  // if (archivePrompt == null) {
  //   print('未找到角色存档模板');
  //   return;
  // }
  

  // // 遍历所有角色并生成存档
  // for (var character in characterController.characters) {
  //   // 创建一个临时的ChatModel，用于构建提示词
  //   var prompt = archivePrompt.content;
  //   prompt = PromptModel.BuildCharacterSystemPrompt(prompt, character);
  //   //prompt = archivePrompt.BuildRelationsPrompt(prompt, character, characterController, null);
    
  //   // 更新角色的archive属性
  //   character.archive = prompt;
  // }

  // // 保存更新后的角色数据
  // characterController.saveCharacters();
  // print("版本迁移成功!");
}