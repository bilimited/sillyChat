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
  bool _isSortingMode = false; // 新增状态：是否处于排序模式

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

  // 分组模式的视图
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
          // 分组内容
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
  
  // 排序模式的视图
  Widget _reorderableListWidget(BuildContext context) {
    // 中文注释: ReorderableListView.builder 是 Flutter 的一个内置组件, 它能够创建一个可重新排序的列表。用户可以通过长按并拖动列表项来改变它们的顺序。
    return ReorderableListView.builder(
      itemCount: characterController.characters.length,
      itemBuilder: (context, index) {
        final contact = characterController.characters[index];
        // 中文注释: 为了让 ReorderableListView 能够正确识别和移动项目, 每个列表项都必须有一个唯一的 Key。
        return Container(
          key: ValueKey(contact.id),
          child: _contractWidget(context, contact),
        );
      },
      onReorder: (int oldIndex, int newIndex) {
        // 当用户拖拽结束后, 此回调函数会被调用
        setState(() {
          // 如果项目被向下拖动, newIndex 会比实际的插入位置大 1
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          // 更新 characterController 中的数据顺序
          final character = characterController.characters.removeAt(oldIndex);
          characterController.characters.insert(newIndex, character);
        });
      },
    );
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
      trailing: _isSortingMode 
        ? const Icon(Icons.drag_handle) // 排序模式下显示拖拽图标
        : IconButton(
            onPressed: () {
              customNavigate(PersonalPage(character: contact), context: context);
            },
            icon: Icon(Icons.chevron_right)),
      title: Text(contact.roleName),
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
        // 排序模式下禁用点击事件
        if (_isSortingMode) return;
        customNavigate(EditCharacterPage(characterId: contact.id), context: context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Obx(() {
        // 根据是否为排序模式来决定显示哪个视图
        if (_isSortingMode) {
          return _reorderableListWidget(context);
        } else {
          return ListView(
            children: [
              ..._groupedContactsWidget(context),
            ],
          );
        }
      }),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 排序模式切换按钮
          FloatingActionButton.small(
            heroTag: 'sort_button', // 中文注释: 为多个 FloatingActionButton 提供唯一的 heroTag
            tooltip: _isSortingMode ? '完成排序' : '进入排序',
            onPressed: () {
              setState(() {
                _isSortingMode = !_isSortingMode;
              });
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                _isSortingMode ? Icons.check : Icons.sort,
                key: ValueKey<bool>(_isSortingMode), // 中文注释: 为 AnimatedSwitcher 的子组件提供 Key 以触发动画
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 新增角色按钮
          FloatingActionButton(
            heroTag: 'add_button',
            tooltip: '新增角色',
            child: const Icon(Icons.add),
            onPressed: () {
              customNavigate(EditCharacterPage(), context: context);
            },
          ),
        ],
      ),
    );
  }
}