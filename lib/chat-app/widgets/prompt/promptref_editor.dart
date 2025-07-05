import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/prompt/edit_prompt.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';

import '../../providers/prompt_controller.dart';
import '../../pages/prompt/prompt_manager.dart';

// 列表项可以是消息或提示词ID

class PromptRefEditor extends StatefulWidget {
  final List<int> initialItems;
  final Function(List<int>)? onItemsChanged;

  const PromptRefEditor({
    Key? key,
    required this.initialItems,
    this.onItemsChanged,
  }) : super(key: key);

  @override
  _PromptRefEditorState createState() => _PromptRefEditorState();
}

class _PromptRefEditorState extends State<PromptRefEditor> {
  final PromptController _promptController = Get.find();
  late List<int> _items;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _isExpanded = {};

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  void _updateItems() {
    if (widget.onItemsChanged != null) {
      widget.onItemsChanged!(_items);
    }
  }

  Future<void> _handlePromptTap(int promptId) async {
    final selectedId = await Get.to(() => PromptManagerPage(isSelector: true));
    if (selectedId != null) {
      setState(() {
        final index = _items.indexOf(promptId);
        if (index != -1) {
          _items[index] = selectedId;
          _updateItems();
        }
      });
    }
  }

  Future<void> _addNewPrompt() async {
    final selectedId = await customNavigate(PromptManagerPage(isSelector: true,),context: context) ;
    if (selectedId != null) {
      setState(() {
        _items.add(selectedId);
        _updateItems();
      });
    }
  }

  void _deleteItem(dynamic item) {
    setState(() {
      _items.remove(item);
      if (item is Map) {
        _controllers.remove(item['id'].toString())?.dispose();
        _focusNodes.remove(item['id'].toString())?.dispose();
        _isExpanded.remove(item['id'].toString());
      }
      _updateItems();
    });
  }

  Widget _buildItemCard(int item) {
      // 提示词显示
      final prompt = _promptController.getPromptById(item);
      if (prompt == null) return SizedBox.shrink();
      
      return Card(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        child: ListTile(
          leading: Icon(Icons.format_quote),
          title: Text(prompt.name),
          subtitle: Text(
            style: TextStyle(fontSize: 14),  
            prompt.content.length > 50 
              ? '${prompt.content.substring(0, 50)}...'
              : prompt.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: (){
                customNavigate(EditPromptPage(prompt: prompt),context: context);
              }
              , icon: Icon(Icons.edit)),
              
              IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: () => _deleteItem(item),
              ),
            ],
          ),
          onTap: () => _handlePromptTap(item),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            minHeight: 10,
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
                _updateItems();
              });
            },
            itemBuilder: (context, index) {
              final item = _items[index];
              return KeyedSubtree(
                key: ValueKey(item),
                child: _buildItemCard(item),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
                  onPressed: _addNewPrompt,
                  icon: Icon(Icons.format_quote),
                  label: Text('添加提示词'),
                ),
        ),
      ],
    );
  }
}
