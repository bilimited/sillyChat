import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/chat/member_selector.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class StoryFormPage extends StatefulWidget {
  StoryFormPage({super.key, this.initialStory});

  final StoryModel? initialStory;

  @override
  State<StoryFormPage> createState() => _StoryFormPageState();
}

class _StoryFormPageState extends State<StoryFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final StoryController _storyController = Get.find<StoryController>();
  final LoreBookController _lorebookController = Get.find<LoreBookController>();
  final ChatOptionController _chatOptionController =
      Get.find<ChatOptionController>();

  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _remarkController;
  late TextEditingController _promptController;

  late List<int> _characterIds;
  late List<int> _lorebookIds;
  int? _chatOptionId;

  bool get _isEditing => widget.initialStory != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final story = widget.initialStory;
    _nameController = TextEditingController(text: story?.name ?? '');
    _remarkController = TextEditingController(text: story?.remark ?? '');
    _promptController = TextEditingController(text: story?.story_prompt ?? '');
    _characterIds = List<int>.from(story?.characterIds ?? []);
    _lorebookIds = List<int>.from(story?.lorebookIds ?? []);
    _chatOptionId = story?.chatOptionId;

    if (_chatOptionId != null &&
        !_chatOptionController.chatOptions.any((o) => o.id == _chatOptionId)) {
      _chatOptionId = null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _remarkController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // --- Save ---

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final remark = _remarkController.text.trim();
    final prompt = _promptController.text.trim();

    if (_isEditing && widget.initialStory != null) {
      final updated = widget.initialStory!.copyWith(
        name: name,
        remark: remark,
        story_prompt: prompt,
        characterIds: _characterIds,
        lorebookIds: _lorebookIds,
        chatOptionId: _chatOptionId,
      );
      await _storyController.updateStory(updated);
    } else {
      final newStory = StoryModel(
        id: const Uuid().v4(),
        name: name,
        remark: remark,
        story_prompt: prompt,
        characterIds: _characterIds,
        lorebookIds: _lorebookIds,
        chatOptionId: _chatOptionId,
      );
      await _storyController.addStory(newStory);
    }
  }

  void _toggleMember(int characterId) {
    setState(() {
      if (_characterIds.contains(characterId)) {
        _characterIds.remove(characterId);
      } else {
        _characterIds.add(characterId);
      }
    });
  }

  // --- Lorebook binding ---

  void _onBindLorebook() {
    final availableBooks = _lorebookController.lorebooks
        .where((lb) => !_lorebookIds.contains(lb.id))
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
                itemBuilder: (_, i) => ListTile(
                  title: Text(availableBooks[i].name),
                  subtitle: Text("共 ${availableBooks[i].items.length} 条条目"),
                  onTap: () {
                    setState(() => _lorebookIds.add(availableBooks[i].id));
                    Get.back();
                  },
                ),
              ),
      ),
    ));
  }

  void _onCreateAndBindLorebook() {
    final lb = LorebookModel.emptyWorldBook();
    _lorebookController.addLorebook(lb);
    setState(() => _lorebookIds.add(lb.id));
    customNavigate(LoreBookEditorPage(lorebook: lb), context: context);
  }

  // --- Tab views ---

  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '名称',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入故事名称' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _remarkController,
          decoration: InputDecoration(
            labelText: '备注',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _promptController,
          decoration: InputDecoration(
            labelText: '提示词',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          minLines: 4,
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入故事提示词' : null,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('参与角色'),
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final selectedChars = _characterIds
              .map((id) => Get.find<CharacterController>().getCharacterById(id))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedChars.isNotEmpty)
                ...selectedChars.map((char) => ListTile(
                      leading: AvatarImage.round(char.avatar, 18),
                      title: Text(char.roleName),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _toggleMember(char.id),
                      ),
                    )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showMemberSelector(context),
                icon: const Icon(Icons.person_add),
                label: const Text('添加角色'),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- 世界书绑定 ---
        _buildSectionTitle('世界书绑定'),
        const SizedBox(height: 8),
        if (_lorebookIds.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('未绑定任何世界书',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          )
        else
          ..._lorebookIds.map((id) {
            final lb = _lorebookController.getLorebookById(id);
            return ListTile(
              title: Text(lb?.name ?? '未知世界书'),
              subtitle: Text("共 ${lb?.items.length ?? 0} 条条目"),
              trailing: IconButton(
                icon: const Icon(Icons.link_off),
                onPressed: () => setState(() => _lorebookIds.remove(id)),
              ),
              onTap: () => lb != null
                  ? customNavigate(LoreBookEditorPage(lorebook: lb),
                      context: context)
                  : null,
            );
          }),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _onBindLorebook,
              icon: const Icon(Icons.link),
              label: const Text('选择已有'),
            ),
            TextButton.icon(
              onPressed: _onCreateAndBindLorebook,
              icon: const Icon(Icons.add),
              label: const Text('新建绑定'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- 聊天预设 ---
        _buildSectionTitle('聊天预设'),
        const SizedBox(height: 8),
        Obx(() {
          return Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _chatOptionId,
                  decoration: const InputDecoration(
                    labelText: '绑定预设',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('无 (使用默认)'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('无 (使用默认)')),
                    ..._chatOptionController.chatOptions
                        .map((opt) => DropdownMenuItem<int?>(
                              value: opt.id,
                              child: Text(opt.name,
                                  overflow: TextOverflow.ellipsis),
                            )),
                  ],
                  onChanged: (v) => setState(() => _chatOptionId = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_suggest),
                onPressed: () =>
                    customNavigate(ChatOptionsManagerPage(), context: context),
              ),
            ],
          );
        }),
      ],
    );
  }

  void _showMemberSelector(BuildContext context) {
    Get.dialog(StatefulBuilder(
      builder: (dialogContext, dialogSetState) {
        return AlertDialog(
          title: const Text('选择角色'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: MemberSelector(
              selectedMembers: _characterIds,
              onToggleMember: (id) {
                _toggleMember(id);
                dialogSetState(() {});
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('完成'),
            ),
          ],
        );
      },
    ));
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) => _save(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑故事' : '添加故事'),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '基本信息'),
              Tab(text: '高级设置'),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicInfoTab(),
              _buildAdvancedTab(),
            ],
          ),
        ),
      ),
    );
  }
}
