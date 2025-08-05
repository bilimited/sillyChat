import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/regex_model.dart';
import 'package:flutter_example/chat-app/pages/regex/edit_regex.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STRegexImporter.dart';
import 'package:flutter_example/chat-app/widgets/filePickerWindow.dart';
import 'package:get/get.dart';

class RegexListEditor extends StatefulWidget {
  final List<RegexModel> regexList;
  final Function(List<RegexModel>) onChanged;

  RegexListEditor({Key? key, required this.regexList, required this.onChanged})
      : super(key: key);

  @override
  State<RegexListEditor> createState() => _RegexListEditorState();
}

class _RegexListEditorState extends State<RegexListEditor> {
  void _onChanged() {
    widget.onChanged(widget.regexList);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final RegexModel item = widget.regexList.removeAt(oldIndex);
      widget.regexList.insert(newIndex, item);
    });
    _onChanged();
  }

  Future<void> _navigateToEditScreen(
      {RegexModel? regexModel, int? index}) async {
    final result = await customNavigate(
        RegexEditScreen(
          regexModel: regexModel,
        ),
        context: context);

    if (result != null) {
      setState(() {
        if (index != null) {
          // 编辑现有规则
          widget.regexList[index] = result;
        } else {
          // 新增规则
          widget.regexList.add(result);
        }
      });
      _onChanged();
    }
  }

  void _deleteRegex(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除正则'),
          content: Text('确定要删除"${widget.regexList[index].name}"吗？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('删除', style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() {
                  final String deletedName = widget.regexList[index].name;
                  widget.regexList.removeAt(index);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${deletedName}" 已删除。')),
                  );
                  _onChanged();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        widget.regexList.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rule_folder_sharp,
                        size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '没有正则表达式',
                      style: TextStyle(fontSize: 14, color: colors.outline),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              )
            : Expanded(
                // constraints: BoxConstraints(
                //   minHeight: 10,
                // ),
                child: ReorderableListView.builder(
                  
                  shrinkWrap: true,
                  // padding: const EdgeInsets.all(10.0),
                  itemCount: widget.regexList.length,
                  itemBuilder: (context, index) {
                    final regex = widget.regexList[index];
                    return Card(
                      key: ValueKey(
                          regex.id), // ReorderableListView要求每个item有唯一的key
                      margin: const EdgeInsets.symmetric(vertical: 5.0),

                      child: ListTile(
                        title: Text(
                          regex.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                            color: regex.enabled
                                ? colors.onSurface
                                : colors.outline,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '模式: ${regex.pattern}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: colors.outline, fontSize: 12),
                            ),
                            Text(
                              '替换: ${regex.replacement.isEmpty ? '(无替换)' : regex.replacement}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: colors.outline, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                              ),
                              onPressed: () => _deleteRegex(index),
                              tooltip: '删除',
                            ),
                          ],
                        ),
                        onTap: () => _navigateToEditScreen(
                            regexModel: regex, index: index),
                      ),
                    );
                  },
                  onReorder: _onReorder,
                ),
              ),
        SizedBox(
          height: 10,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _navigateToEditScreen();
              },
              label: Text('添加正则'),
              icon: Icon(Icons.add),
            ),
            SizedBox(
              width: 16,
            ),
            ElevatedButton.icon(
              onPressed: () {
                int startId = DateTime.now().microsecondsSinceEpoch;
                int id = 0;
                FileImporter(
                  title: '导入正则',
                  warning:
                      '请注意:本应用仍在测试阶段，未兼容SillyTavern的部分功能，导入后部分字段可能会丢失。因此，正则表达式行为可能与在 SillyTavern 中的表现有所不同。',
                  paramList: [],
                  allowedExtensions: ['json'],
                  multiple: true,
                  onImport: (fileName, fileContent, selectedParams,path) {
                    final regex = STRegexImporter.fromJson(
                        json.decode(fileContent), fileName, id: startId + id);
                    id ++;
                    if (regex != null) {
                      setState(() {
                        widget.regexList.add(regex);
                      });
                    }
                  },
                  onAllSuccess: (fileCount, selectedParams) {
                    _onChanged();
                    Get.snackbar('导入成功', '已导入${fileCount}个正则');
                  },
                ).pickAndProcessFile(context);
              },
              label: Text('导入ST正则'),
              icon: Icon(Icons.download),
            ),
          ],
        )
      ],
    );
  }
}
