import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_gallery.dart';
import 'package:flutter_example/chat-app/pages/character/more_firstmessage_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/character/edit_relationship.dart';
import 'package:flutter_example/chat-app/widgets/expandable_text_field.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';
import '../../providers/character_controller.dart';

class EditCharacterPage extends StatefulWidget {
  final int? characterId;
  const EditCharacterPage({Key? key, this.characterId}) : super(key: key);

  @override
  State<EditCharacterPage> createState() => _EditCharacterPageState();
}

class _EditCharacterPageState extends State<EditCharacterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _characterController = Get.find<CharacterController>();
  final _lorebookController = Get.find<LoreBookController>();

  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _nickNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _archiveController;
  late TextEditingController _categoryController;
  late TextEditingController _briefController;
  late TextEditingController _firstMessageController;

  int? _bindOption;
  String? _avatarPath;
  String? _backgroundPath;
  CharacterModel? _character;

  bool get isEditMode => widget.characterId != null;
  bool get isEditPlayer => widget.characterId == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (isEditMode) {
      _character = _characterController.getCharacterById(widget.characterId!);
    }

    _nameController = TextEditingController(text: _character?.remark ?? '');
    _nickNameController = TextEditingController(text: _character?.roleName ?? '');
    _descriptionController = TextEditingController(text: _character?.description ?? '');
    _archiveController = TextEditingController(text: _character?.archive ?? '');
    _categoryController = TextEditingController(text: _character?.category ?? '');
    _briefController = TextEditingController(text: _character?.brief ?? '');
    _avatarPath = _character?.avatar;
    _backgroundPath = _character?.backgroundImage;
    _firstMessageController = TextEditingController(text: _character?.firstMessage ?? '');
    _bindOption = _character?.bindOptionId;

    if (!ChatOptionController.of().chatOptions.any((o) => o.id == _bindOption)) {
      _bindOption = null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _nickNameController.dispose();
    _descriptionController.dispose();
    _archiveController.dispose();
    _categoryController.dispose();
    _briefController.dispose();
    _firstMessageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isAvatar) async {
    final t = DateTime.now().hashCode;
    final path = await ImageUtils.selectAndCropImage(context,
        isCrop: isAvatar, fileName: '${isAvatar ? "avatar" : "bg"}_${widget.characterId}_$t');

    if (path != null) {
      setState(() => isAvatar ? _avatarPath = path : _backgroundPath = path);
    }
  }

  CharacterModel? _saveCharacter() {
    if (!_formKey.currentState!.validate()) return null;

    return CharacterModel(
      id: _character?.id ?? DateTime.now().millisecondsSinceEpoch,
      remark: _nameController.text,
      roleName: _nickNameController.text,
      avatar: _avatarPath ?? '',
      description: _descriptionController.text,
      category: _categoryController.text.isEmpty ? "默认" : _categoryController.text,
      lorebookIds: _character?.lorebookIds ?? [],
      firstMessage: _firstMessageController.text,
    )
      ..moreFirstMessage = _character?.moreFirstMessage ?? []
      ..backgroundImage = _backgroundPath
      ..brief = _briefController.text
      ..relations = _character?.relations ?? {}
      ..archive = _archiveController.text
      ..messageStyle = _character?.messageStyle ?? MessageStyle.common
      ..bindOptionId = _bindOption
      ..memoryBookId = _character?.memoryBookId;
  }

  Future<void> _save() async {
    final character = _saveCharacter();
    if (character == null) return;
    isEditMode ? await _characterController.updateCharacter(character) : await _characterController.addCharacter(character);
  }

  Future<void> _deleteCharacter() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个角色吗？'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed == true) {
      await _characterController.deleteCharacter(widget.characterId!);
      Get.back();
    }
  }

  // --- 视图组件 ---

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
  }

  Widget _buildBasicInfoTab() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(true),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: colors.surfaceContainerHighest,
                  child: ClipOval(
                    child: _avatarPath != null
                        ? AvatarImage(fileName: _avatarPath!)
                        : Icon(Icons.add_photo_alternate, size: 40, color: colors.onSurfaceVariant),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.primary,
                      child: Icon(Icons.camera_alt, size: 14, color: colors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _nickNameController,
          decoration: const InputDecoration(labelText: '角色名称', hintText: '输入角色显示的昵称'),
        ),
        const SizedBox(height: 16),
        ExpandableTextField(
          controller: _briefController,
          decoration: const InputDecoration(labelText: '简略介绍', helperText: "角色的简短描述"),
          minLines: 2,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        ExpandableTextField(
          controller: _firstMessageController,
          decoration: const InputDecoration(labelText: '开场白', helperText: "角色的第一条对话"),
          extraActions: [
            if (_character != null)
              buildIconTextButton(
                      context,
                      text: '更多选项',
                      icon: Icons.more_horiz,
                      onPressed: () {
                        customNavigate(
                            MoreFirstMessagePage(character: _character!),
                            context: context);
                      },
                    )
          ],
        ),
        const SizedBox(height: 16),
        ExpandableTextField(
          controller: _archiveController,
          decoration: const InputDecoration(labelText: '角色设定', helperText: '角色的背景、性格、能力等核心设定'),
          maxLines: 15,
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 1. 一般设置
        ExpansionTile(
          shape: const Border(),          // 去掉展开时的顶部和底部线条
  collapsedShape: const Border(), // 去掉折叠时的线条
          initiallyExpanded: true,
          title: _buildSectionTitle('一般设置'),
          // leading: const Icon(Icons.settings_outlined),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: '分类', hintText: '例如：动漫、原创、历史'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MessageStyle>(
              value: _character?.messageStyle,
              decoration: const InputDecoration(labelText: '消息气泡样式'),
              items: const [
                DropdownMenuItem(value: MessageStyle.common, child: Text('普通')),
                DropdownMenuItem(value: MessageStyle.narration, child: Text('旁白')),
                DropdownMenuItem(value: MessageStyle.summary, child: Text('摘要')),
              ],
              onChanged: (v) => setState(() => _character?.messageStyle = v ?? MessageStyle.common),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _bindOption,
                    decoration: const InputDecoration(labelText: '绑定预设'),
                    hint: const Text('选择聊天预设'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('无 (使用默认)')),
                      ...Get.find<ChatOptionController>().chatOptions.map((opt) => DropdownMenuItem(
                            value: opt.id,
                            child: Text(opt.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _bindOption = v),
                  ),
                ),
                IconButton(onPressed: () => customNavigate(ChatOptionsManagerPage(), context: context), icon: const Icon(Icons.settings_suggest)),
              ],
            ),
            const SizedBox(height: 16),
            _buildBgSelector(),
          ],
        ),
        SizedBox(height: 16,),
        // 2. 世界书绑定
        ExpansionTile(
                    shape: const Border(),          // 去掉展开时的顶部和底部线条
  collapsedShape: const Border(), // 去掉折叠时的线条
          initiallyExpanded: true,
          title: _buildSectionTitle('世界书绑定'),
          // leading: const Icon(Icons.menu_book_outlined),
          childrenPadding: const EdgeInsets.all(8),
          children: [
            if (_character?.lorebookIds.isEmpty ?? true)
              const Padding(padding: EdgeInsets.all(16), child: Text('未绑定任何世界书', style: TextStyle(color: Colors.grey)))
            else
              ...(_character!.lorebookIds.map((id) {
                final lb = _lorebookController.getLorebookById(id);
                return ListTile(
                  title: Text(lb?.name ?? '未知世界书'),
                  subtitle: Text("共 ${lb?.items?.length ?? 0} 条条目"),
                  trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => setState(() => _character!.lorebookIds.remove(id))),
                  onTap: () => customNavigate(LoreBookEditorPage(lorebook: LoreBookController.of.getLorebookById(id)), context: context),
                );
              })),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(onPressed: _onBindLorebook, label: const Text('选择已有'), icon: const Icon(Icons.link)),
                TextButton.icon(onPressed: _onCreateLorebook, label: const Text('新建绑定'), icon: const Icon(Icons.add)),
              ],
            ),
          ],
        ),
SizedBox(height: 16,),
        // 3. 角色记忆
        ExpansionTile(
                    shape: const Border(),          // 去掉展开时的顶部和底部线条
  collapsedShape: const Border(), // 去掉折叠时的线条
          initiallyExpanded: true,
          title: _buildSectionTitle('角色记忆'),
          // leading: const Icon(Icons.memory_outlined),
          childrenPadding: const EdgeInsets.all(8),
          children: [
            if (_character?.memoryBook == null)
              Center(
                child: TextButton.icon(
                  onPressed: _onCreateMemory,
                  label: const Text('为角色开启记忆本'),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              )
            else
              ListTile(
                title: Text(_character!.memoryBook?.name ?? ''),
                subtitle: Text("共 ${_character!.memoryBook?.items?.length ?? 0} 条记忆"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: _onDeleteMemory,
                ),
                onTap: () => customNavigate(LoreBookEditorPage(lorebook: LoreBookController.of.getLorebookById(_character!.memoryBookId!)), context: context),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBgSelector() {
    return GestureDetector(
      onTap: () => _pickImage(false),
      onLongPress: () => setState(() => _backgroundPath = null),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: _backgroundPath != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_backgroundPath!), fit: BoxFit.cover, width: double.infinity))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(Icons.add_photo_alternate_outlined, color: Colors.grey), Text('设置角色聊天背景', style: TextStyle(color: Colors.grey, fontSize: 12))],
              ),
      ),
    );
  }

  // --- 操作逻辑 ---

  void _onBindLorebook() {
    final availableBooks = _lorebookController.lorebooks
        .where((lb) => lb.type == LorebookType.character && !(_character?.lorebookIds.contains(lb.id) ?? false))
        .toList();

    Get.dialog(AlertDialog(
      title: const Text('绑定世界书'),
      content: SizedBox(
        width: double.maxFinite,
        child: availableBooks.isEmpty
            ? const Text("暂无可用世界书")
            : ListView.builder(
                shrinkWrap: true,
                itemCount: availableBooks.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(availableBooks[i].name),
                  onTap: () {
                    setState(() => _character?.lorebookIds.add(availableBooks[i].id));
                    Get.back();
                  },
                ),
              ),
      ),
    ));
  }

  void _onCreateLorebook() {
    final lb = LorebookModel.emptyCharacterBook();
    _lorebookController.addLorebook(lb);
    setState(() => _character?.lorebookIds.add(lb.id));
    customNavigate(LoreBookEditorPage(lorebook: lb), context: context);
  }

  void _onCreateMemory() {
    final lb = LorebookModel.emptyMemoryBook().copyWith(name: "${_character?.roleName ?? '角色'}的记忆");
    _lorebookController.addLorebook(lb);
    setState(() => _character?.memoryBookId = lb.id);
  }

  void _onDeleteMemory() async {
    final confirmed = await Get.dialog<bool>(AlertDialog(
      title: const Text('确认删除'),
      content: const Text('将永久清除角色记忆，是否继续？'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
        TextButton(onPressed: () => Get.back(result: true), child: const Text('确认')),
      ],
    ));
    if (confirmed == true && _character?.memoryBookId != null) {
      _lorebookController.deleteLorebook(_character!.memoryBookId!);
      setState(() => _character!.memoryBookId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) => _save(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditPlayer ? '编辑用户' : (isEditMode ? '编辑角色' : '新建角色')),
          bottom: isEditPlayer ? null : TabBar(controller: _tabController, tabs: const [Tab(text: '基本信息'), Tab(text: '其他设置'), Tab(text: '关系')]),
          actions: isEditPlayer ? [] : [
            IconButton(icon: const Icon(Icons.image_outlined), onPressed: () => customNavigate(CharacterGalleryPage(path: "${SettingController.of.getImagePathSync()}/${widget.characterId}/"), context: context)),
            IconButton(icon: const Icon(Icons.copy_all), onPressed: () {
              if (_character != null) {
                _characterController.characterCilpBoard.value = _character!.copyWith(roleName: '${_character!.roleName}_副本');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
              }
            }),
            if (isEditMode) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteCharacter),
          ],
        ),
        body: Form(
          key: _formKey,
          child: isEditPlayer
              ? _buildPlayerSetting()
              : TabBarView(controller: _tabController, children: [
                  _buildBasicInfoTab(),
                  _buildSettingsTab(),
                  Padding(padding: const EdgeInsets.all(16), child: EditRelationship(character: _character, relations: _character?.relations ?? {}, onChanged: (r) => setState(() => _character?.relations = r))),
                ]),
        ),
      ),
    );
  }

  Widget _buildPlayerSetting() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(true),
            child: CircleAvatar(radius: 50, child: ClipOval(child: _avatarPath != null ? AvatarImage(fileName: _avatarPath!) : const Icon(Icons.person, size: 50))),
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(controller: _nickNameController, decoration: const InputDecoration(labelText: '我的名字')),
        const SizedBox(height: 16),
        TextFormField(controller: _briefController, decoration: const InputDecoration(labelText: '个人简介'), maxLines: 2),
        const SizedBox(height: 24),
        _buildSectionTitle('聊天背景'),
        const SizedBox(height: 8),
        _buildBgSelector(),
      ],
    );
  }
}