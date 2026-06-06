import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/common/category_manage_page.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/utils/ModalUtil.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STCharacterImporter.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:flutter_example/main.dart';
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

class _ContactsPageState extends State<ContactsPage>
    with SingleTickerProviderStateMixin {
  final Map<String, bool> _expandedState = {};
  final characterController = Get.find<CharacterController>();

  // 当前激活的 tab：角色 / 助手
  CharacterType _activeTab = CharacterType.character;
  late TabController _tabController;

  // 当前视图模式，默认列表
  CharacterViewMode _viewMode = CharacterViewMode.list;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _activeTab = _tabController.index == 0
          ? CharacterType.character
          : CharacterType.agent);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 按类型和分组过滤
  List<MapEntry<String, List<CharacterModel>>> get _filteredAndGroupedContacts {
    final allCharacters = characterController
        .getAllCharactersAndAgent()
        .where((c) => c.type == _activeTab)
        .toList();

    final map = allCharacters.fold(<String, List<CharacterModel>>{}, (map, contact) {
      map.putIfAbsent(contact.category, () => []);
      map[contact.category]!.add(contact);
      return map;
    });

    // 按 categoryConfigs 排序
    final configNames = characterController.categoryConfigs
        .map((c) => c.name)
        .toList();
    final entries = map.entries.toList();
    entries.sort((a, b) {
      final aIsDefault = a.key.isEmpty || a.key == '默认';
      final bIsDefault = b.key.isEmpty || b.key == '默认';
      if (aIsDefault && !bIsDefault) return 1;
      if (!aIsDefault && bIsDefault) return -1;

      final aIdx = configNames.indexOf(a.key);
      final bIdx = configNames.indexOf(b.key);
      if (aIdx >= 0 && bIdx >= 0) return aIdx.compareTo(bIdx);
      if (aIdx >= 0) return -1;
      if (bIdx >= 0) return 1;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  void _showAddCharacterDialog(BuildContext context) {
    customNavigate(
      EditCharacterPage(initialType: _activeTab),
      context: context, 
    );
  }

  void _openCategoryManage(BuildContext context) {
    customNavigate(
      CategoryManagePage(
        title: '联系人分组',
        categories: characterController.categoryConfigs,
        entityCount: (name) {
          if (name.isEmpty || name == '默认') {
            return characterController.characters
                .where((c) =>
                    c.bindStoryId == null &&
                    (c.category.isEmpty || c.category == '默认'))
                .length;
          }
          return characterController
              .getCharactersByCategory(name)
              .where((c) => c.bindStoryId == null)
              .length;
        },
        onAdd: (name) => characterController.addCategory(name),
        onRename: (oldName, newName) =>
            characterController.renameCategory(oldName, newName),
        onDelete: (name) => characterController.deleteCategory(name),
        onReorder: (oldIndex, newIndex) =>
            characterController.reorderCategories(oldIndex, newIndex),
      ),
      context: context,
    );
  }

  void _openChat(CharacterModel contact) {
    ChatController.of.openCharacterLatestChat(contact);
    Get.back();
  }

  void _editCharacter(BuildContext context, CharacterModel contact) {
    customNavigate(
      EditCharacterPage(characterId: contact.id),
      context: context,
    );
  }

  void _deleteCharacter(BuildContext context, CharacterModel contact) {
    showConfirmDialog(
      context: context,
      title: "确定删除该角色?",
      content: "该操作不可撤销。",
      onConfirm: () {
        CharacterController.of.deleteCharacter(contact.id);
      },
    );
  }

  void _handleCharacterMenuAction(
    BuildContext context,
    CharacterModel contact,
    String value,
  ) {
    switch (value) {
      case 'edit':
        _editCharacter(context, contact);
        break;
      case 'delete':
        _deleteCharacter(context, contact);
        break;
    }
  }

  Widget _buildCharacterMenu(
    BuildContext context,
    CharacterModel contact, {
    Color? iconColor,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 20, color: iconColor),
      onSelected: (value) => _handleCharacterMenuAction(context, contact, value),
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Text('编辑角色'),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text('删除角色'),
        ),
      ],
    );
  }

  // 获取模式切换按钮的图标
  IconData _getViewModeIcon() {
    switch (_viewMode) {
      case CharacterViewMode.list:
        return Icons.view_agenda_rounded;
      case CharacterViewMode.card:
        return Icons.grid_view_rounded;
      case CharacterViewMode.grid:
        return Icons.view_list_rounded;
    }
  }

  Widget _buildListTile(BuildContext context, CharacterModel contact) {
    final isDesktop = SillyChatApp.isDesktop();

    return StatefulBuilder(
      builder: (context, setInnerState) {
        bool hovered = false;

        return MouseRegion(
          onEnter: (_) => setInnerState(() => hovered = true),
          onExit: (_) => setInnerState(() => hovered = false),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: ImageUtils.getProvider(contact.avatar),
              radius: 24.0,
            ),
            title: Text(contact.roleName),
            subtitle: contact.brief != null
                ? Text(
                    contact.brief!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: (!isDesktop || hovered)
                ? _buildCharacterMenu(context, contact)
                : const SizedBox(width: 24),
            onTap: () => _openChat(contact),
          ),
        );
      },
    );
  }

  Widget _buildCardTile(BuildContext context, CharacterModel contact) {
    final bgImage = contact.backgroundImage ?? contact.avatar;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 2.0,
      child: InkWell(
        onTap: () => _openChat(contact),
        child: Container(
          height: 110.0,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.roleName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildCharacterMenu(
                      context,
                      contact,
                      iconColor: Colors.white,
                    ),
                  ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile(BuildContext context, CharacterModel contact) {
    final bgImage = contact.backgroundImage ?? contact.avatar;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 2.0,
      child: InkWell(
        onTap: () => _openChat(contact),
        child: SizedBox(
          height: 200.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: ImageUtils.getProvider(bgImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4.0,
                right: 4.0,
                child: Material(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20.0),
                  child: _buildCharacterMenu(
                    context,
                    contact,
                    iconColor: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 12.0,
                right: 12.0,
                bottom: 12.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.roleName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.brief != null) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        contact.brief!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentForMode(
    BuildContext context,
    List<CharacterModel> contacts,
  ) {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
      floatingActionButton: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (CharacterController.of.characterCilpBoard.value != null)
              FloatingActionButton(
                heroTag: 'paste_character',
                onPressed: () {
                  characterController.addCharacter(
                    characterController.characterCilpBoard.value!,
                  );
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
              tooltip: _activeTab == CharacterType.agent ? '新增助手' : '新增角色',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            InnerAppBar(
              title: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.onSurface,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: '角色'),
                  Tab(text: '助手'),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.label_outline,
                    color: theme.colorScheme.onSurface,
                  ), 
                  onPressed: () => _openCategoryManage(context),
                  tooltip: '管理分组',
                ),
                IconButton(
                  icon: Icon(
                    _getViewModeIcon(),
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: () {
                    setState(() {
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
          // 监听角色列表变化以触发重建
          characterController.characters.length;
          final groupedContacts = _filteredAndGroupedContacts;

          if (groupedContacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _activeTab == CharacterType.agent
                        ? Icons.smart_toy_outlined
                        : Icons.person_off,
                    size: 60.0,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    _activeTab == CharacterType.agent ? '暂无助手' : '暂无角色',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0),
            itemCount: groupedContacts.length,
            itemBuilder: (context, index) {
              final entry = groupedContacts[index];
              final groupKey = entry.key;
              final contacts = entry.value;

              final isExpanded = _expandedState[groupKey] ?? true;

              return Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('${groupKey}_${_activeTab.name}'),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    _expandedState[groupKey] = expanded;
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