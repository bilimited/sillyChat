import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/pages/character/personal_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final Map<String, bool> _expandedState = {};

  final characterController = Get.find<CharacterController>();

  Map<String, List<CharacterModel>> get groupedContacts {
    return characterController.characters.fold(<String, List<CharacterModel>>{},
        (map, contact) {
      if (!map.containsKey(contact.category)) {
        map[contact.category] = [];
      }
      map[contact.category]!.add(contact);
      return map;
    });
  }

  Iterable<Column> _groupedContactsWidget(BuildContext context) {
    final theme = Theme.of(context);
    return groupedContacts.entries.map((entry) {
      _expandedState.putIfAbsent(entry.key, () => true);
      return Column(
        children: [
          // 分组标题
          ListTile(
            title: Text(
              "${entry.key} (${entry.value.length})",
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 14,
              ),
            ),
            trailing: AnimatedRotation(
              turns: _expandedState[entry.key]! ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              child: const Icon(Icons.expand_more),
            ),
            onTap: () {
              setState(() {
                _expandedState[entry.key] = !_expandedState[entry.key]!;
              });
            },
          ),
          // 分组内容（将此处分组内容的列表项改为可拖拽的）
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expandedState[entry.key]!
                  ? Column(
                      children: entry.value
                          .map((contact) => _contractWidget(context, contact))
                          .toList())
                  : const SizedBox(),
            ),
          ),
        ],
      );
    });
  }

  ListTile _contractWidget(BuildContext context, CharacterModel contact) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: Image.file(File(contact.avatar)).image,
            radius: 29,
          ),

        ],
      ),
      trailing: IconButton(onPressed: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            // 之前是导航到PersonalPage
            builder: (context) => PersonalPage(character: contact,),
          ),
        );
      }, icon: Icon(Icons.chevron_right)),
      title: Text(contact.name),
      subtitle: contact.brief != null
          ? Text(
              contact.brief!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
              maxLines: 2,
            )
          : null,
      onTap: () {
        customNavigate(EditCharacterPage(characterId: contact.id,));
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     // 之前是导航到PersonalPage
        //     builder: (context) => EditCharacterPage(characterId: contact.id),
        //   ),
        // );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Obx(() => ListView(
            children: [
              // 顶部搜索栏
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  hintText: "搜索联系人",
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainer),
                ),
              ),
              // 联系人分组列表
              ..._groupedContactsWidget(context)
            ],
          )),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Get.to(EditCharacterPage());
        },
      ),
    );
  }
}
