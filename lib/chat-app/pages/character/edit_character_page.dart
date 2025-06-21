import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/main_page.dart';
import 'package:flutter_example/chat-app/pages/character/gen_character_prompt.dart';
import 'package:flutter_example/chat-app/widgets/character/edit_relationship.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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
  final _imagePicker = ImagePicker();

  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _nickNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _archiveController;
  late TextEditingController _categoryController;
  late TextEditingController _ageController;
  late TextEditingController _briefController;

  String? _avatarPath;
  String? _backgroundPath;
  late String _selectedGender;
  CharacterModel? _character;
  bool get isEditMode => widget.characterId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.characterId != null) {
      _character = _characterController.getCharacterById(widget.characterId!);
    }

    _nameController = TextEditingController(text: _character?.name ?? '');
    _nickNameController =
        TextEditingController(text: _character?.roleName ?? '');
    _descriptionController =
        TextEditingController(text: _character?.description ?? '');
    _archiveController = TextEditingController(text: _character?.archive ?? '');
    _categoryController =
        TextEditingController(text: _character?.category ?? '');
    _ageController =
        TextEditingController(text: (_character?.age ?? 18).toString());
    _briefController = TextEditingController(text: _character?.brief ?? '');
    _selectedGender = _character?.gender ?? '女';
    _avatarPath = _character?.avatar;
    _backgroundPath = _character?.backgroundImage;

  }

  Future<void> _pickImage(bool isAvatar) async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isAvatar) {
          _avatarPath = image.path;
        } else {
          _backgroundPath = image.path;
        }
      });
    }
  }

  CharacterModel? _saveCharacter() {
    if (!_formKey.currentState!.validate()) return null; // 字段校验不通过无提示

    return CharacterModel(
      id: _character?.id ?? DateTime.now().millisecondsSinceEpoch,
      name: _nameController.text,
      roleName: _nickNameController.text,
      avatar: _avatarPath ?? '',
      description: _descriptionController.text,
      category:
          _categoryController.text.isEmpty ? "默认" : _categoryController.text,
    )
      ..gender = _selectedGender
      ..age = int.parse(_ageController.text)
      ..backgroundImage = _backgroundPath
      ..brief = _briefController.text
      ..relations = _character?.relations ?? {}
      ..archive = _archiveController.text
      ..messageStyle = _character?.messageStyle ?? MessageStyle.common;
  }

  Future<void> _saveAndBack() async {
    final character = _saveCharacter();
    if (character == null) return;
    if (isEditMode) {
      await _characterController.updateCharacter(character);
    } else {
      await _characterController.addCharacter(character);
    }

    Get.back();
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
      Get.to(() => MainPage());
    }
  }

  Future<void> _copyCharacter() async {
    if (_character == null) return;

    var char = _character!.copy();
    _characterController.addCharacter(char);
    Get.back();
    Get.snackbar("拷贝成功", "角色已拷贝");
  }

  Widget _buildBasicInfoTab() {
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
                border: Border.all(color: Colors.grey.shade300, width: 2),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: _avatarPath != null
                    ? Image.file(
                        File(_avatarPath!),
                        fit: BoxFit.cover,
                      )
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
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '角色名称',
                    border: UnderlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return '请输入角色名称';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nickNameController,
                  decoration: const InputDecoration(
                    labelText: '别名(聊天使用名称)',
                    border: UnderlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return '请输入角色别名';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(
                          labelText: '年龄',
                          border: UnderlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: '性别',
                          border: UnderlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _briefController,
                  decoration: const InputDecoration(
                    labelText: '简略介绍',
                    border: UnderlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _archiveController,
                    decoration: const InputDecoration(
                      labelText: '角色介绍',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () async {
                        final char = _saveCharacter();
                        if (char == null) {
                          Get.snackbar("错误", "字段填写存在问题!");
                          return;
                        }
                        final result = await Get.to<String?>(
                            () => GenCharacterPromptPage(character: char));
                        if (result != null) {
                          setState(() {
                            _archiveController.text = result;
                          });
                        }
                      },
                      child: Text("生成角色介绍")),
                ],
              )),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
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
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MessageStyle>(
                  value: _character?.messageStyle,
                  decoration: const InputDecoration(
                    labelText: '对话样式',
                    border: UnderlineInputBorder(),
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
                const SizedBox(height: 16),
                const Text(
                  '背景图片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _pickImage(false),
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
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? '编辑角色' : '新建角色'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '基本信息'),
            Tab(text: '其他设置'),
          ],
        ),
        actions: [
          IconButton(onPressed: _copyCharacter, icon: const Icon(Icons.copy)),
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteCharacter,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBasicInfoTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAndBack,
        icon: Icon(isEditMode ? Icons.save : Icons.create),
        label: Text(
          isEditMode ? '保存修改' : '创建角色',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _ageController.dispose();
    _briefController.dispose();
    super.dispose();
  }
}
