import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/prompt/edit_prompt.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import '../../models/prompt_model.dart';
import '../../providers/prompt_controller.dart';
import '../../pages/prompt/prompt_manager.dart';

class PromptEditor extends StatefulWidget {
  final List<PromptModel> prompts;
  final Function(List<PromptModel>)? onPromptsChanged;

  const PromptEditor({
    Key? key,
    required this.prompts,
    this.onPromptsChanged,
  }) : super(key: key);

  @override
  _PromptEditorState createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  final PromptController _promptController = Get.find();

  @override
  void initState() {
    super.initState();
  }

  void _updatePrompts() {
    if (widget.onPromptsChanged != null) {
      widget.onPromptsChanged!(widget.prompts);
    }
  }

  void _deletePrompt(PromptModel prompt) {
    setState(() {
      widget.prompts.remove(prompt);
      _updatePrompts();
    });
  }

  Future<void> _replacePrompt(int index) async {
    final int? selected =
        await customNavigate(PromptManagerPage(isSelector: true),context: context);
    // await Get.to(() => PromptManagerPage(isSelector: true));
    if (selected == null) return;

    final selectedPrompt = _promptController.getPromptById(selected);
    if (selectedPrompt != null) {
      setState(() {
        widget.prompts[index] = PromptModel(
          id: DateTime.now().millisecondsSinceEpoch,
          content: selectedPrompt.content,
          role: selectedPrompt.role,
          name: selectedPrompt.name,
          category: selectedPrompt.category,
        );
        _updatePrompts();
      });
    }
  }

  Widget _buildPromptCard(PromptModel prompt, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            prompt.role,
            style: TextStyle(fontSize: 11),
          ),
        ),
        title: Text(
          prompt.name.isEmpty
              ? prompt.content.isEmpty
                  ? "空白消息"
                  : prompt.content
              : prompt.name,
          style: TextStyle(fontSize: 13),
          maxLines: 3,
        ),
        onTap: () async {
          PromptModel? newPrompt = await customNavigate(EditPromptPage(
            prompt: prompt,
            editTempPrompt: true,
          ),context: context);
          if (newPrompt == null) {
            return;
          }
          setState(() {
            prompt.name = newPrompt.name;
            prompt.role = newPrompt.role;
            prompt.content = newPrompt.content;
          });
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.swap_horiz),
              onPressed: () => _replacePrompt(index),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => _deletePrompt(prompt),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 10,
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.prompts.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final prompt = widget.prompts.removeAt(oldIndex);
                widget.prompts.insert(newIndex, prompt);
                _updatePrompts();
              });
            },
            itemBuilder: (context, index) {
              return KeyedSubtree(
                key: ValueKey(widget.prompts[index].id),
                child: _buildPromptCard(widget.prompts[index], index),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final newPrompt = PromptModel(
                    id: DateTime.now().millisecondsSinceEpoch,
                    content: '',
                    role: 'system',
                    name: '',
                    category: PromptCategory.custom,
                  );
                  setState(() {
                    widget.prompts.add(newPrompt);
                    _updatePrompts();
                  });
                },
                icon: Icon(Icons.add),
                label: Text('添加空白'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final int? selected =
                      await customNavigate(PromptManagerPage(isSelector: true),context: context);
                  if (selected == null) return;
                  final selectedPrompt =
                      _promptController.getPromptById(selected);
                  if (selectedPrompt != null) {
                    final promptCopy = PromptModel(
                      id: DateTime.now().millisecondsSinceEpoch,
                      content: selectedPrompt.content,
                      role: selectedPrompt.role,
                      name: selectedPrompt.name,
                      category: selectedPrompt.category,
                    );
                    setState(() {
                      widget.prompts.add(promptCopy);
                      _updatePrompts();
                    });
                  }
                },
                icon: Icon(Icons.format_quote),
                label: Text('从现有添加'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
