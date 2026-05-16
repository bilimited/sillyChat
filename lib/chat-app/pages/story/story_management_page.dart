import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';
import 'package:flutter_example/chat-app/pages/story/story_form_page.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/common/app_option_card.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';

class StoryManagementPage extends GetView<StoryController> {
  const StoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // 没有 AppBar
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              final story = stories[index];
              return _StoryCard(
                story: story,
                colorScheme: colorScheme,
                onTap: () {
                  ChatController.of.openStoryLatestChat(story);
                  Get.back();
                  // 预留：点击故事卡片的处理事件
                },
                onDelete: () => _confirmDelete(context, story.id),
              );
            },
          );
        }),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 预留：添加故事的处理事件
          customNavigate(StoryFormPage(), context: context);
        },
        tooltip: '添加故事',
        child: const Icon(Icons.add),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return AppOptionCard<String>(
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
              Text(
                '编辑故事',
              ),
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
