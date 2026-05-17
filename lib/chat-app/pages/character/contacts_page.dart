import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/pages/character/profile_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STCharacterImporter.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';

// 定义三种显示模式
enum CharacterViewMode { list, card, grid }

class ContactsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const ContactsPage({Key? key, this.scaffoldKey}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final Map<String, bool> _expandedState = {};
  final characterController = Get.find<CharacterController>();

  final TextEditingController _searchController = TextEditingController();
  final RxString _searchText = ''.obs;

  // 当前视图模式，默认列表
  CharacterViewMode _viewMode = CharacterViewMode.list;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchText.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 搜索和分组逻辑
  Map<String, List<CharacterModel>> get _filteredAndGroupedContacts {
    if (_searchText.value.isEmpty) {
      return characterController.characters
          .fold(<String, List<CharacterModel>>{}, (map, contact) {
        if (!map.containsKey(contact.category)) {
          map[contact.category] = [];
        }
        map[contact.category]!.add(contact);
        return map;
      });
    } else {
      final filteredContacts = characterController.characters
          .where((contact) =>
              contact.roleName
                  .toLowerCase()
                  .contains(_searchText.value.toLowerCase()) ||
              contact.category
                  .toLowerCase()
                  .contains(_searchText.value.toLowerCase()) ||
              (contact.brief?.toLowerCase() ?? '')
                  .contains(_searchText.value.toLowerCase()))
          .toList();

      return filteredContacts.fold(<String, List<CharacterModel>>{},
          (map, contact) {
        if (!map.containsKey(contact.category)) {
          map[contact.category] = [];
        }
        map[contact.category]!.add(contact);
        return map;
      });
    }
  }

  void _showAddCharacterDialog(BuildContext context) {
    customNavigate(const EditCharacterPage(), context: context);
  }

  // 获取模式切换按钮的图标
  IconData _getViewModeIcon() {
    switch (_viewMode) {
      case CharacterViewMode.list:
        return Icons.view_agenda_rounded; // 提示下一个是卡片模式
      case CharacterViewMode.card:
        return Icons.grid_view_rounded; // 提示下一个是大卡片网格模式
      case CharacterViewMode.grid:
        return Icons.view_list_rounded; // 提示下一个是列表模式
    }
  }

  // 1. 列表式 Item
  Widget _buildListTile(BuildContext context, CharacterModel contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: ImageUtils.getProvider(contact.avatar),
        radius: 24.0,
      ),
      title: Text(contact.roleName),
      subtitle: contact.brief != null
          ? Text(
              contact.brief!,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () {
        customNavigate(ProfilePage(character: contact), context: context);
      },
    );
  }

  // 2. 卡片式 Item
  Widget _buildCardTile(BuildContext context, CharacterModel contact) {
    final theme = Theme.of(context);
    final bgImage = contact.backgroundImage ?? contact.avatar;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 2.0,
      child: InkWell(
        onTap: () {
          customNavigate(ProfilePage(character: contact), context: context);
        },
        child: Container(
          height: 70.0,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ImageUtils.getProvider(bgImage),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.centerRight,
                colors: [Colors.black26, Colors.black87],
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.roleName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold),
                ),
                if (contact.brief != null) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    contact.brief!,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13.0),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        customNavigate(
                          EditCharacterPage(characterId: contact.id),
                          context: context,
                        );
                      },
                      icon: const Icon(Icons.edit,
                          size: 18.0, color: Colors.white),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      onPressed: () {
                        ChatController.of.openCharacterLatestChat(contact);
                        Get.back();
                      },
                      icon: const Icon(Icons.chat,
                          size: 18.0, color: Colors.white),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. 大卡片式 Item
Widget _buildGridTile(BuildContext context, CharacterModel contact) {
  final bgImage = contact.backgroundImage ?? contact.avatar;
  return Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
    elevation: 2.0,
    child: InkWell(
      onTap: () {
        customNavigate(ProfilePage(character: contact), context: context);
      },
      child: SizedBox(          // 用 SizedBox 固定高度，替代 GridView 的 childAspectRatio
        height: 200.0,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ImageUtils.getProvider(bgImage),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.roleName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.brief != null) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    contact.brief!,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.0),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
Widget _buildContentForMode(
    BuildContext context, List<CharacterModel> contacts) {
  switch (_viewMode) {
    case CharacterViewMode.list:
      return Column(
        children: contacts.map((c) => _buildListTile(context, c)).toList(),
      );
    case CharacterViewMode.card:
      return Column(
        children: contacts.map((c) => _buildCardTile(context, c)).toList(),
      );
    case CharacterViewMode.grid:
      final List<Widget> rows = [];
      for (int i = 0; i < contacts.length; i += 2) {
        final left = contacts[i];
        final right = (i + 1 < contacts.length) ? contacts[i + 1] : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildGridTile(context, left)),
                const SizedBox(width: 12.0),
                Expanded(
                  child: right != null
                      ? _buildGridTile(context, right)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: Column(children: rows),
      );
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (CharacterController.of.characterCilpBoard.value != null)
                FloatingActionButton(
                  heroTag: 'paste_character',
                  onPressed: () {
                    characterController.addCharacter(
                        characterController.characterCilpBoard.value!);
                    setState(() {
                      characterController.characterCilpBoard.value = null;
                    });
                  },
                  tooltip: '粘贴角色',
                  child: const Icon(Icons.paste),
                ),
              const SizedBox(height: 16.0),
              FloatingActionButton(
                onPressed: () => _showAddCharacterDialog(context),
                tooltip: '新增角色',
                child: const Icon(Icons.add),
              ),
            ],
          )),
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            InnerAppBar(
              title: Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索角色',
                    hintStyle:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20.0,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minHeight: 32.0,
                      minWidth: 32.0,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 12.0),
                    border: InputBorder.none, // 移除下划线
                    suffixIcon: _searchText.value.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                size: 20.0,
                                color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () {
                              _searchController.clear();
                              _searchText.value = '';
                            },
                          )
                        : null,
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  cursorColor: theme.colorScheme.primary,
                ),
              ),
              actions: [
                // 视图模式切换按钮
                IconButton(
                  icon: Icon(_getViewModeIcon(),
                      color: theme.colorScheme.onSurface),
                  onPressed: () {
                    setState(() {
                      // 循环切换视图模式
                      _viewMode = CharacterViewMode.values[
                          (_viewMode.index + 1) %
                              CharacterViewMode.values.length];
                    });
                  },
                  tooltip: '切换显示模式',
                ),
                const SizedBox(width: 8.0),
              ],
            ),
          ];
        },
        body: Obx(() {
          final groupedContacts = _filteredAndGroupedContacts;
          final isSearching = _searchText.value.isNotEmpty;

          if (groupedContacts.isEmpty && isSearching) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 60.0, color: theme.colorScheme.outline),
                  const SizedBox(height: 16.0),
                  Text('未找到匹配的角色',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0), // 防止FAB挡住最后的内容
            itemCount: groupedContacts.length,
            itemBuilder: (context, index) {
              final entry = groupedContacts.entries.elementAt(index);
              final groupKey = entry.key;
              final contacts = entry.value;

              final isExpanded =
                  isSearching || (_expandedState[groupKey] ?? true);

              return Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('${groupKey}_$isSearching'),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    if (!isSearching) {
                      _expandedState[groupKey] = expanded;
                    }
                  },
                  title: Text(
                    "$groupKey (${contacts.length})",
                    style: TextStyle(
                      color: theme.colorScheme.outline,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  children: [
                    _buildContentForMode(context, contacts),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
