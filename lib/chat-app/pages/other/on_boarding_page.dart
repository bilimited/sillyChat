import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/pages/other/api_edit.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STCharacterImporter.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STConfigImporter.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_remix/flutter_remix.dart'; // 使用 Remix 图标库，设计更现代

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class _OnBoardingPageState extends State<OnBoardingPage> {
  final _introKey = GlobalKey<IntroductionScreenState>();

  // 表单数据状态
  // 用户设置
  File? _avatarImage;
  final _nameController = TextEditingController();
  final _introController = TextEditingController();

  // API 设置
  String? _selectedModel;
  bool _isCustomModel = false;
  final _apiKeyController = TextEditingController();

  // 导入配置
  File? _characterCardImage;
  PlatformFile? _presetFile;

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  // --- 事件处理方法 ---

  // 选择头像
  Future<void> _pickAvatar() async {
    final pickedFile = await ImageUtils.selectAndCropImage(
      context,
    );
    //await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile);
      });
    }
  }

  // 选择角色卡
  Future<void> _pickCharacterCard() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _characterCardImage = File(pickedFile.path);
      });
    }
  }

  // 选择预设文件
  Future<void> _pickPresetFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _presetFile = result.files.single;
      });
    }
  }

  // 点击“更多”模型的处理
  void _onMoreModelsTapped() async {
    final api =
        await customNavigate<ApiModel?>(ApiEditPage(), context: context);
    if (api != null) {
      setState(() {
        _isCustomModel = true;
        _selectedModel = api.modelName;
      });
    }
  }

  // 引导页完成后的统一数据处理
  void _onOnboardingComplete() async {
    if (_selectedModel == null) {
      SillyChatApp.snackbar(context, '未选择模型!');
      return;
    }
    if (_apiKeyController.text.isEmpty && !_isCustomModel) {
      SillyChatApp.snackbar(context, '未输入API Key!');
      return;
    }

    final vault = Get.find<VaultSettingController>();
    final characters = Get.find<CharacterController>();

    final CharacterModel user = CharacterModel(
        id: 0,
        remark: '你',
        roleName: _nameController.text,
        avatar: _avatarImage?.path ?? '',
        category: '默认',
        brief: _introController.text);

    characters.addCharacter(user);

    if (!_isCustomModel) {
      final _selectedServiceProvider =
          ServiceProvider.findProviderByModelName(_selectedModel!);

      final ApiModel api = ApiModel(
          id: DateTime.now().microsecondsSinceEpoch,
          apiKey: _apiKeyController.text,
          displayName: _selectedModel!,
          modelName: _selectedModel!,
          url: ServiceProvider.providerData[_selectedServiceProvider]
                  ?['defaultUrl'] ??
              'Error',
          provider: _selectedServiceProvider);

      vault.addApi(api);
    }

    vault.isShowOnBoardPage.value = false;

    if (_presetFile != null && _presetFile!.path != null) {
      //导入预设：自动使用第一个api
      File(_presetFile!.path!).readAsString().then((content) {
        STConfigImporter.fromJson(json.decode(content), _presetFile!.name);
      });
    } else {
      // 不导入预设：创建一个空预设，使用第一个Api
      ChatOptionController.of().addChatOption(ChatOptionModel.empty()
        ..requestOptions =
            LLMRequestOptions(messages: [], apiId: vault.apis.first.id));
    }

    if (_characterCardImage != null) {
      final decoded =
          await STCharacterImporter.readPNGExts(_characterCardImage!);
      final char = await STCharacterImporter.fromJson(json.decode(decoded),
          _characterCardImage.toString(), _characterCardImage!.path);
      if (char != null) {
        characters.addCharacter(char);
      }
    }
  }

  void _onSkip() {
    VaultSettingController.of().isShowOnBoardPage.value = false;
  }
  // --- UI 构建方法 ---

  // 构建统一的页面装饰
  PageDecoration _buildPageDecoration() {
    return PageDecoration(
      titleTextStyle: Theme.of(context)
          .textTheme
          .headlineMedium!
          .copyWith(fontWeight: FontWeight.normal),
      bodyTextStyle: Theme.of(context).textTheme.bodyLarge!,
      pageColor: Theme.of(context).colorScheme.background,
      imagePadding: const EdgeInsets.only(bottom: 24),
      bodyPadding: const EdgeInsets.all(16),
    );
  }

  // 构建用户设置页面
  Widget _buildUserPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,

              // 用Container包裹，添加边框
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  backgroundImage:
                      _avatarImage != null ? FileImage(_avatarImage!) : null,
                  child: _avatarImage == null
                      ? Icon(FlutterRemix.user_add_line,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text("你的昵称 *", style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: '输入一个响亮的名字',
            ),
          ),
          const SizedBox(height: 16),
          Text("个人简介 (可选)", style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _introController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '简单介绍一下自己',
            ),
          ),
        ],
      ),
    );
  }

  // 构建 API 设置页面
  Widget _buildApiPage() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget modelButton(String name, String value) {
      final isSelected = _selectedModel == value;
      return InkWell(
        onTap: () => setState(() {
          _selectedModel = value;
          _isCustomModel = false;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? colorScheme.primaryContainer : colorScheme.surface,
            border: Border.all(
                color: isSelected ? colorScheme.primary : colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      );
    }

    Widget moreButton() {
      final isSelected = _isCustomModel;
      return InkWell(
        onTap: _onMoreModelsTapped,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? colorScheme.primaryContainer : colorScheme.surface,
            border: Border.all(
                color: isSelected ? colorScheme.primary : colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _isCustomModel ? _selectedModel ?? '未知模型' : '更多',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("选择一个模型", style: textTheme.labelLarge),
          const SizedBox(height: 8),
          modelButton('Gemini 2.5-Pro', 'gemini-2.5-pro'),
          const SizedBox(height: 8),
          modelButton('Gemini 2.5-Flash', 'gemini-2.5-flash'),
          const SizedBox(height: 8),
          modelButton('DeepSeek-Chat(官方)', 'deepseek-chat'),
          const SizedBox(height: 8),
          modelButton('DeepSeek-V3(硅基流动)', 'deepseek-ai/DeepSeek-V3'),
          const SizedBox(height: 8),
          moreButton(),
          const SizedBox(height: 12),
          if (!_isCustomModel) ...[
            Text("输入你的 API Key", style: textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'API-KEY',
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // 构建导入配置页面
  Widget _buildImportPage() {
    Widget buildImportButton({
      required VoidCallback onTap,
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget? content,
      required BuildContext context,
      Widget? background, // 新增：可选的背景 Widget
    }) {
      final colorScheme = Theme.of(context).colorScheme;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          // ClipRRect 确保背景和渐变等子元素遵循圆角设置
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // 如果提供了背景，则将其放置在最底层，并添加一个背景色渐变层

                if (background != null) ...[
                  Positioned.fill(
                    child: background,
                  ),
                  // 背景色渐变
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            colorScheme.surface.withOpacity(1),
                            colorScheme.surface.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // 原始卡片内容
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(icon, size: 32, color: colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(subtitle,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (content != null) content,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          buildImportButton(
            context: context,
            onTap: _pickCharacterCard,
            icon: FlutterRemix.image_add_line,
            title: '导入角色卡',
            subtitle: '选择一张图片作为角色卡',
            content: null,
            background: _characterCardImage != null
                ? Image.file(_characterCardImage!,
                    width: 40, height: 40, fit: BoxFit.cover)
                : null,
          ),
          const SizedBox(height: 16),
          buildImportButton(
            context: context,
            onTap: _pickPresetFile,
            icon: FlutterRemix.file_add_line,
            title: '导入预设',
            subtitle: '选择一个.json文件',
            content: _presetFile != null
                ? Container(
                    width: 100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _presetFile!.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 32),
          Text('注意:本软件不完全兼容酒馆，建议不要导入过于复杂的角色卡。')
        ],
      ),
    );
  }

  Widget _buildTitleWidget(String title, String subTitle) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subTitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IntroductionScreen(
        key: _introKey,
        // 全局配置
        globalBackgroundColor: Theme.of(context).colorScheme.background,
        // 页面列表
        pages: [
          PageViewModel(
            titleWidget: _buildTitleWidget("引导之始", "选择你的头像和名称"),
            bodyWidget: _buildUserPage(),
            decoration: _buildPageDecoration(),
          ),
          PageViewModel(
            titleWidget: _buildTitleWidget("连接你的API", "将来这里会有一个测试通信功能"),
            bodyWidget: _buildApiPage(),
            decoration: _buildPageDecoration(),
          ),
          PageViewModel(
            titleWidget: _buildTitleWidget("即将开始", "导入SillyTavern角色卡和预设(可选)"),
            bodyWidget: _buildImportPage(),
            decoration: _buildPageDecoration(),
          ),
        ],
        // 按钮与导航
        onDone: _onOnboardingComplete,
        onSkip: _onSkip, // 跳过也视为完成，进入主页
        showSkipButton: true,
        skip: const Text('跳过', style: TextStyle(fontWeight: FontWeight.w600)),
        next: const Icon(Icons.arrow_forward),
        done: const Text('完成', style: TextStyle(fontWeight: FontWeight.w600)),

        // 指示器样式
        dotsDecorator: DotsDecorator(
          size: const Size.square(10.0),
          activeSize: const Size(20.0, 10.0),
          activeColor: Theme.of(context).colorScheme.primary,
          color: Colors.black26,
          spacing: const EdgeInsets.symmetric(horizontal: 3.0),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
        ),
      ),
    );
  }
}
