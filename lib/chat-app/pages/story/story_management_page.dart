import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';
import 'package:flutter_example/chat-app/pages/story/story_form_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/common/app_option_card.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:flutter_example/chat-app/widgets/stack_avatar.dart';
import 'package:get/get.dart';

const String _kUncategorizedKey = '__uncategorized__';
const String _kUncategorizedLabel = '未分类';

class StoryManagementPage extends GetView<StoryController> {
  const StoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            InnerAppBar(title: const Text('故事管理')),
          ];
        },
        body: Obx(() {
          final stories = controller.stories;

          if (stories.isEmpty) {
            return Center(
              child: Text(
                '还没有故事，点击右下角按钮添加',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final grouped = _groupByCategory(stories);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final entry = grouped[index];
              return _CategorySection(
                categoryKey: entry.key,
                label: entry.key == _kUncategorizedKey
                    ? _kUncategorizedLabel
                    : entry.key,
                stories: entry.value,
                colorScheme: colorScheme,
                onStoryTap: (story) {
                  ChatController.of.openStoryLatestChat(story);
                  Get.back();
                },
                onStoryDelete: (story) => _confirmDelete(context, story.id),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          customNavigate(StoryFormPage(), context: context);
        },
        tooltip: '添加故事',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<MapEntry<String, List<StoryModel>>> _groupByCategory(
      List<StoryModel> stories) {
    final map = <String, List<StoryModel>>{};
    for (final story in stories) {
      final key =
          story.category.trim().isEmpty ? _kUncategorizedKey : story.category;
      map.putIfAbsent(key, () => []).add(story);
    }

    final entries = map.entries.toList();
    entries.sort((a, b) {
      if (a.key == _kUncategorizedKey) return 1;
      if (b.key == _kUncategorizedKey) return -1;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个故事吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true) {
      await controller.deleteStory(id);
    }
  }
}

class _CategorySection extends StatefulWidget {
  final String categoryKey;
  final String label;
  final List<StoryModel> stories;
  final ColorScheme colorScheme;
  final ValueChanged<StoryModel> onStoryTap;
  final ValueChanged<StoryModel> onStoryDelete;

  const _CategorySection({
    required this.categoryKey,
    required this.label,
    required this.stories,
    required this.colorScheme,
    required this.onStoryTap,
    required this.onStoryDelete,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.stories.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: widget.stories
                .map((story) => _StoryCard(
                      story: story,
                      colorScheme: widget.colorScheme,
                      onTap: () => widget.onStoryTap(story),
                      onDelete: () => widget.onStoryDelete(story),
                    ))
                .toList(),
          ),
          secondChild: const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final StoryModel story;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _StoryCard({
    required this.story,
    required this.colorScheme,
    this.onTap,
    this.onDelete,
  });

  List<String> _collectAvatars() {
    final controller = CharacterController.of;
    final seen = <int>{};
    final avatars = <String>[];

    void add(int id) {
      if (id <= 0 || seen.contains(id)) return;
      final char = controller.getCharacterById(id);
      if (char.avatar.isNotEmpty) {
        avatars.add(char.avatar);
      }
      seen.add(id);
    }

    for (final id in story.characterIds) {
      add(id);
    }
    for (final char in controller.getCharactersByStoryId(story.id)) {
      add(char.id);
    }
    return avatars;
  }

  @override
  Widget build(BuildContext context) {
    final avatars = _collectAvatars();

    return AppOptionCard<String>(
      leading: avatars.isEmpty
          ? CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.menu_book_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            )
          : StackAvatar(
              avatarUrls: avatars,
              avatarSize: 40,
              spacing: 14,
              maxDisplayCount: 3,
            ),
      title: story.name,
      subTitle: story.remark.isNotEmpty
          ? Text(
              story.remark,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      options: [
        AppCardOptionItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit),
              const SizedBox(width: 12),
              Text('编辑故事'),
            ],
          ),
        ),
        AppCardOptionItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: colorScheme.error),
              const SizedBox(width: 12),
              Text(
                '删除故事',
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'delete') {
          onDelete?.call();
        } else if (value == "edit") {
          customNavigate(
              StoryFormPage(
                initialStory: story,
              ),
              context: context);
        }
      },
      onTap: onTap,
    );
  }
}
