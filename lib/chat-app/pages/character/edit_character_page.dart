import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/pages/character/more_firstmessage_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
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

class _EditCharacterPageState extends State<EditCharacterPage>
    with SingleTickerProviderStateMixin {
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

  late int? _bindOption;

  String? _avatarPath;
  String? _backgroundPath;
  List<CharacterMemory> _memories = [];

  CharacterModel? _character;
  bool get isEditMode => widget.characterId != null;
  bool get isEditPlayer => widget.characterId == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.characterId != null) {
      _character = _characterController.getCharacterById(widget.characterId!);
    }

    _nameController = TextEditingController(text: _character?.remark ?? '');
    _nickNameController =
        TextEditingController(text: _character?.roleName ?? '');
    _descriptionController =
        TextEditingController(text: _character?.description ?? '');
    _archiveController = TextEditingController(text: _character?.archive ?? '');
    _categoryController =
        TextEditingController(text: _character?.category ?? '');
    // _ageController =
    //     TextEditingController(text: (_character?.age ?? 18).toString());
    _briefController = TextEditingController(text: _character?.brief ?? '');
    // _selectedGender = _character?.gender ?? '女';
    _avatarPath = _character?.avatar;
    _backgroundPath = _character?.backgroundImage;
    _firstMessageController =
        TextEditingController(text: _character?.firstMessage ?? '');

    _bindOption = widget.characterId != null
        ? _characterController
            .getCharacterById(widget.characterId!)
            .bindOptionId
        : null;
    _memories = _character?.memories ?? [];

    if (!ChatOptionController.of()
        .chatOptions
        .map((option) => option.id)
        .contains(_bindOption)) {
      _bindOption = null;
    }
  }

  Future<void> _pickImage(bool isAvatar) async {
    // final XFile? image =
    //     await _imagePicker.pickImage(source: ImageSource.gallery);
    final t = DateTime.now().hashCode;
    final path = await ImageUtils.selectAndCropImage(context,
        isCrop: isAvatar, fileName: 'avatar_${widget.characterId}_${t}');

    if (path != null) {
      setState(() {
        if (isAvatar) {
          if (_avatarPath != null) {}

          _avatarPath = path;
        } else {
          _backgroundPath = path;
        }
      });
    }
  }

  // 复制角色并返回
  CharacterModel? _saveCharacter() {
    if (!_formKey.currentState!.validate()) return null; // TODO:字段校验不通过无提示

    return CharacterModel(
      id: _character?.id ?? DateTime.now().millisecondsSinceEpoch,
      remark: _nameController.text,
      roleName: _nickNameController.text,
      avatar: _avatarPath ?? '',
      description: _descriptionController.text,
      category:
          _categoryController.text.isEmpty ? "默认" : _categoryController.text,
      lorebookIds: _character?.lorebookIds ?? [],
      firstMessage: _firstMessageController.text,
      memories: _memories,
    )
      ..moreFirstMessage = _character?.moreFirstMessage ?? []
      ..backgroundImage = _backgroundPath
      ..brief = _briefController.text
      ..relations = _character?.relations ?? {}
      ..archive = _archiveController.text
      ..messageStyle = _character?.messageStyle ?? MessageStyle.common
      ..backups = _character?.backups ?? []
      ..bindOptionId = _bindOption;
  }

  // void _applyBackup(CharacterModel backup) {
  //   setState(() {
  //     _nickNameController.text = backup.roleName;
  //     _nameController.text = backup.remark;
  //     _descriptionController.text = backup.description ?? '';
  //     _categoryController.text = backup.category;
  //     _briefController.text = backup.brief ?? '';
  //     _archiveController.text = backup.archive;
  //     _firstMessageController.text = backup.firstMessage ?? '';

  //     // 头像和背景不拷贝
  //     //_avatarPath = backup.avatar;
  //     //_backgroundPath = backup.backgroundImage;

  //     // 关系：深拷贝
  //     Map<int, Relation> newRelations = {};
  //     for (var relation in backup.relations.values) {
  //       newRelations[relation.targetId] = relation.copy();
  //     }
  //     _character!.relations = Map.from(newRelations);

  //     _character!.messageStyle = backup.messageStyle;
  //   });
  // }

  Future<void> _save() async {
    final character = _saveCharacter();
    if (character == null) return;
    if (isEditMode) {
      await _characterController.updateCharacter(character);
    } else {
      await _characterController.addCharacter(character);
    }
  }

  Future<void> _deleteCharacter() async {
    if (!isEditMode) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个角色吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _characterController.deleteCharacter(widget.characterId!);
      Get.back();
    }
  }

  Future<void> _copyCharacter() async {
    if (_character == null) return;

    var char = _character!.copyWith(roleName: _character!.roleName + '的副本');
    _characterController.characterCilpBoard.value = char;
    SillyChatApp.snackbar(context, '角色已复制到剪贴板');
  }

  Widget _buildBackgroundimageSelecter() {
    return GestureDetector(
      onTap: () => _pickImage(false),
      onLongPress: () {
        setState(() {
          _backgroundPath = null;
        });
      },
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: _backgroundPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_backgroundPath!),
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 40,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击选择背景图片',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(true),
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: _avatarPath != null
                    ? AvatarImage(fileName: _avatarPath!)
                    : Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: Colors.grey.shade600,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10.0), // 卡片内部的内边距
            child: Column(
              mainAxisSize: MainAxisSize.min, // 让 Column 尽可能小地占用垂直空间
              crossAxisAlignment: CrossAxisAlignment.stretch, // 子组件水平方向拉伸
              children: [
                // 角色名称和备注
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nickNameController,
                        decoration: const InputDecoration(
                          labelText: '角色名称',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0), // 间隔
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '备注',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // 间隔
                // 简略介绍

                ExpandableTextField(
                  controller: _briefController,
                  decoration: const InputDecoration(
                    labelText: '简略介绍(可选)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16), // 间隔
                // 首句台词
                ExpandableTextField(
                  controller: _firstMessageController,
                  decoration: InputDecoration(
                    labelText: '开场白(可选)',
                  ),
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

                const SizedBox(height: 16), // 间隔
                const Divider(), // 分隔线
                const SizedBox(height: 16), // 分隔线后的间隔
                // 角色介绍
                ExpandableTextField(
                  controller: _archiveController,
                  decoration: const InputDecoration(
                    labelText: '角色介绍',
                  ),
                  style: TextStyle(fontSize: 15),
                  maxLines: 16,
                ),
                const SizedBox(height: 10), // 间隔
                // 生成角色介绍按钮
                // ElevatedButton(
                //   onPressed: () async {
                //     final char = _saveCharacter();
                //     if (char == null) {
                //       Get.snackbar("错误", "字段填写存在问题!");
                //       return;
                //     }
                //     final result = await customNavigate<String>(
                //         GenCharacterPromptPage(character: char),
                //         context: context);

                //     if (result != null) {
                //       setState(() {
                //         _archiveController.text = result;
                //       });
                //     }
                //   },
                //   child: const Text("生成角色介绍"),
                // ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '人物关系',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                EditRelationship(
                  character: _character,
                  relations: _character?.relations ?? {},
                  onChanged: (relations) {
                    if (_character != null) {
                      setState(() {
                        _character!.relations = relations;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: '分类',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MessageStyle>(
                  value: _character?.messageStyle,
                  decoration: const InputDecoration(
                    labelText: '消息气泡样式',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: MessageStyle.common, child: Text('普通')),
                    DropdownMenuItem(
                        value: MessageStyle.narration, child: Text('旁白')),
                    DropdownMenuItem(
                        value: MessageStyle.summary, child: Text('摘要')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (_character != null) {
                        _character!.messageStyle = value ?? MessageStyle.common;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                        child: DropdownButtonFormField<int?>(
                      // <-- 1. 确保泛型是 int?
                      value: _bindOption,
                      decoration: const InputDecoration(
                        label: Text('绑定预设'),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      hint: const Text('选择聊天预设'),
                      items: [
                        // <-- 2. 手动添加一个“空白”选项
                        DropdownMenuItem<int?>(
                          value: null, // 这个 item 的值是 null
                          child: Text(
                            '无(使用默认预设)',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outline),
                          ), // 显示给用户的文本
                        ),
                        // 3. 使用展开操作符(...)将原来的列表合并进来
                        ...Get.find<ChatOptionController>()
                            .chatOptions
                            .map((option) {
                          return DropdownMenuItem<int>(
                            // 这里的泛型保持 int 也可以，会自动转换
                            value: option.id,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: Text(
                                option.name, // 建议模板字符串里不要加大括号，除非必要
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (int? value) {
                        setState(() {
                          // <-- 4. 记得调用 setState 来更新UI
                          _bindOption = value;
                        });
                      },
                    )),
                    IconButton(
                        onPressed: () {
                          customNavigate(ChatOptionsManagerPage(),
                              context: context);
                        },
                        icon: Icon(Icons.list)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '背景图片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBackgroundimageSelecter()
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_character != null)
          Card(
            // 角色绑定的世界书管理
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '世界书绑定',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_character != null && _character!.lorebookIds.isEmpty)
                    const SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          '当前角色未绑定任何世界书',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else if (_character != null &&
                      _character!.lorebookIds.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _character!.lorebookIds.map((id) {
                        final lorebook =
                            _lorebookController.getLorebookById(id);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            onTap: () {
                              if (lorebook != null) {}
                            },
                            child: ListTile(
                              onTap: () {
                                final lb = LoreBookController.of
                                    .getLorebookById(lorebook?.id ?? -1);
                                //TODO: LoreBookEditorPage不应该传入lorebook，会导致未更新。
                                customNavigate(
                                    LoreBookEditorPage(
                                      lorebook: lb,
                                    ),
                                    context: context);
                              },
                              title: Text(lorebook?.name ?? '未知世界书'),
                              subtitle: Text(
                                // TODO: 改成总Token，
                                "共${lorebook?.items?.length ?? '未知'}条",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.link_off),
                                onPressed: () {
                                  setState(() {
                                    _character!.lorebookIds.remove(id);
                                  });
                                },
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                          onPressed: () {
                            if (_character == null) {
                              return;
                            }
                            final lorebooks = _lorebookController.lorebooks
                                .where((lorebook) =>
                                    lorebook.type == LorebookType.character)
                                .where((lorebook) => !_character!.lorebookIds
                                    .contains(lorebook.id))
                                .toList();

                            // 显示一个弹窗，从中选择一个世界书
                            Get.dialog(
                              AlertDialog(
                                title: const Text('选择世界书'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: lorebooks.length,
                                    itemBuilder: (context, index) {
                                      final lorebook = lorebooks[index];
                                      return ListTile(
                                        title: Text(lorebook.name),
                                        onTap: () {
                                          setState(() {
                                            _character?.lorebookIds
                                                .add(lorebook.id);
                                          });
                                          Get.back();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          label: const Text('绑定角色书'),
                          icon: const Icon(Icons.link)),
                      SizedBox(
                        width: 8,
                      ),
                      TextButton.icon(
                          onPressed: () {
                            final lb = LorebookModel.emptyCharacterBook();
                            LoreBookController.of.addLorebook(lb);
                            setState(() {
                              _character!.lorebookIds.add(lb.id);
                            });

                            customNavigate(
                                LoreBookEditorPage(
                                  lorebook: lb,
                                ),
                                context: context);
                          },
                          label: const Text('添加角色书'),
                          icon: const Icon(Icons.add)),
                    ],
                  ),
                ],
              ),
            ),
          )
      ],
    );
  }

  // 用户（Id==0）的设置界面
  Widget _buildPlayerSetting() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(true),
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: _avatarPath != null
                    ? AvatarImage(fileName: _avatarPath!)
                    : Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: Colors.grey.shade600,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _nickNameController,
                  decoration: const InputDecoration(
                    labelText: '角色名称',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return '角色名称';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _briefController,
                  decoration: const InputDecoration(
                    labelText: '简略介绍',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MessageStyle>(
                  value: _character?.messageStyle,
                  decoration: const InputDecoration(
                    labelText: '消息气泡样式',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: MessageStyle.common, child: Text('普通')),
                    DropdownMenuItem(
                        value: MessageStyle.narration, child: Text('旁白')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (_character != null) {
                        _character!.messageStyle = value ?? MessageStyle.common;
                      }
                    });
                  },
                ),
                SizedBox(
                  height: 32,
                ),
                _buildBackgroundimageSelecter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          _save();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditPlayer
                ? '编辑用户角色'
                : isEditMode
                    ? '编辑角色'
                    : '新建角色'),
            bottom: isEditPlayer
                ? null
                : TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: '基本信息'),
                      Tab(text: '其他设置'),
                      // Tab(text: '编辑记忆'),
                    ],
                  ),
            actions: isEditPlayer
                ? []
                : [
                    IconButton(
                        onPressed: _copyCharacter,
                        icon: const Icon(Icons.copy)),
                    if (isEditMode)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _deleteCharacter,
                      ),
                  ],
          ),
          body: Form(
            key: _formKey,
            child: isEditPlayer
                ? _buildPlayerSetting()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBasicInfoTab(),
                      _buildSettingsTab(),
                      // _buildMemoryTab()
                    ],
                  ),
          ),
          // floatingActionButton: FloatingActionButton.extended(
          //   onPressed: _save,
          //   icon: Icon(isEditMode ? Icons.save : Icons.create),
          //   label: Text(
          //     isEditMode ? '保存修改' : '创建角色',
          //     style: const TextStyle(fontSize: 16),
          //   ),
          // ),
        ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _briefController.dispose();
    super.dispose();
  }
}
