import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import '../../models/prompt_model.dart';
import '../../providers/prompt_controller.dart';
import 'edit_prompt.dart';

class PromptManagerPage extends StatefulWidget {
  final bool isSelector; // 新增模式标识

  const PromptManagerPage({
    Key? key,
    this.isSelector = false,
  }) : super(key: key);

  @override
  _PromptManagerPageState createState() => _PromptManagerPageState();
}

class _PromptManagerPageState extends State<PromptManagerPage> {
  final PromptController _promptController = Get.find();
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchText = ''.obs;

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

  Widget _buildPromptCard(PromptModel prompt) {
    return Card(
      margin: EdgeInsets.all(4.0),
      child: InkWell(
        onTap: () async {
          if (widget.isSelector) {
            Get.back(result: prompt.id);
          } else {
            customNavigate(EditPromptPage(prompt: prompt),context: context);
          }
        },
        child: ListTile(
          title: Row(
            children: [
              Expanded(child: Text(prompt.name)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  prompt.role,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                '更新时间: ${prompt.updateDate.toString().split('.')[0]}',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
          trailing: widget.isSelector ? null : (prompt.isInChat ? null : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  if (await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('确认删除'),
                      content: Text('确定要删除这个提示词吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('确定'),
                        ),
                      ],
                    ),
                  ) ?? false) {
                    _promptController.deletePrompt(prompt.id);
                  }
                },
              ),
            ],
          )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelector ? '选择提示词' : '常用提示词管理'),
        actions: widget.isSelector ? [] : [
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索提示词...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              var prompts = _promptController.prompts;
              if (widget.isSelector) {
                return ListView.builder(
                  itemCount: prompts.length,
                  
                  itemBuilder: (context, index) {
                    final prompt = prompts[index];
                    return _buildPromptCard(prompt);
                  },
                );
              }

              return ReorderableListView.builder(
                itemCount: prompts.length,
                onReorderStart: (index) {
                  // 可选：添加拖拽开始的视觉反馈
                },
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  // final item = prompts[oldIndex];
                  _promptController.reorderPrompts(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final prompt = prompts[index];
                  return KeyedSubtree(
                    key: ValueKey('${prompt.id}_$index'), // 修改此处，添加索引确保唯一性
                    child: _buildPromptCard(prompt),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: widget.isSelector ? null : FloatingActionButton(
        onPressed: () {
          Get.to(() => EditPromptPage());
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
