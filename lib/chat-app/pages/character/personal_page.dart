import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/chat_list_item.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';

class PersonalPage extends StatefulWidget {
  final CharacterModel character;
  late final int characterId;

  PersonalPage({
    Key? key,
    required this.character,
  }) : super(key: key) {
    characterId = character.id;
  }

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  final _appBarOpacity = ValueNotifier<double>(0.0);

  final characterController = Get.find<CharacterController>();

  CharacterModel get character =>
      characterController.getCharacterById(widget.characterId);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 当滚动超过200时开始改变透明度
    final opacity = (_scrollController.offset - 200) / 100;
    _appBarOpacity.value = opacity.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          ValueListenableBuilder<double>(
            valueListenable: _appBarOpacity,
            builder: (context, opacity, child) => SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor:
                  colors.surfaceContainer.withOpacity(opacity), // 动态背景色
              elevation: opacity > 0 ? 4 : 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: opacity > 0.5 ? colors.onSurface : Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                    onPressed: () {
                      Get.to(() => EditCharacterPage(
                            characterId: widget.characterId,
                          ));
                    },
                    icon: Icon(
                      Icons.settings,
                      color: opacity > 0.5 ? colors.onSurface : Colors.white,
                    )),
              ],

              flexibleSpace: Obx(() => FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        // 背景图
                        character.backgroundImage != null
                            ? Image.file(
                                File(character.backgroundImage!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Image.network(
                                'https://picsum.photos/800/600',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                        // 渐变遮罩 - 修改渐变效果使顶部导航栏区域更清晰
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4), // 顶部加深一些
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.4, 1.0], // 控制渐变位置
                            ),
                          ),
                        ),
                        // 个人信息
                        Positioned(
                          left: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage:
                                    Image.file(File(character.avatar)).image,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                character.roleName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                character.description ?? '',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ),
          ),

          // app头部（包括背景图）

          // 关系列表
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildRelationsList(),
              ],
            ),
          ),

          // 三个子页面的标题
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: colors.onSurface,
                unselectedLabelColor: colors.outlineVariant,
                tabs: const [
                  Tab(text: '聊天'),
                  Tab(text: '笔记'),
                  // Tab(text: '赞过'),
                ],
              ),
            ),
          ),

          // 三个子页面
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatsList(),
                _buildChatsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList() {
    return SizedBox.shrink();
    // final chats = Get.find<ChatController>().getChatsByCharacterId(character.id);

    // return MediaQuery.removePadding(
    //   context: context,
    //   removeTop: true,
    //   child: ListView.builder(
    //     padding: const EdgeInsets.only(top: 8),
    //     itemCount: chats.length,
    //     itemBuilder: (context, index) {
    //       return ChatListItem(
    //         chatId: chats.reversed.toList()[index].id,
    //       );
    //     },
    //   ),
    // );
  }

  Widget _buildRelationsList() {
    if (character.relations.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: character.relations.length,
        itemBuilder: (context, index) {
          final relation = character.relations.values.elementAt(index);
          final targetChar =
              characterController.getCharacterById(relation.targetId);

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Get.to(() => PersonalPage(character: targetChar)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: FileImage(File(targetChar.avatar)),
                  ),
                  const SizedBox(height: 8),
                  // Text(
                  //   relation.nickname ?? targetChar.name,
                  //   style: const TextStyle(fontSize: 12),
                  // ),
                  if (relation.type != null)
                    Text(
                      relation.type!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
