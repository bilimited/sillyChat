import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_example/chat-app/widgets/alert_card.dart';
import 'package:get/get.dart';

/// 可配置的导入参数
class ImportParam {
  final String id;
  final String name;
  bool isSelected;

  ImportParam({required this.id, required this.name, this.isSelected = false});
}

/// 导入完成后的回调函数
/// [fileName] 导入的文件名
/// [fileContent] 导入的文件文本内容
/// [selectedParams] 用户选择的导入参数ID列表
typedef OnImport = void Function(
    String fileName, String fileContent, List<String> selectedParams);

/// 导入多个文件全部完成时的回调函数
typedef OnSuccess = void Function(int fileCount, List<String> selectedParams);

class FileImporter {
  final String? title;
  final String? introduction;
  final String? warning;
  final List<ImportParam> paramList;
  final List<String> allowedExtensions;
  final OnImport onImport;
  final OnSuccess? onAllSuccess;

  final bool multiple;

  // 多选模式时使用此变量
  final List<String> fileNames = [];
  final List<String> fileContents = [];

  FileImporter(
      {Key? key,
      this.title,
      this.introduction,
      required this.paramList,
      required this.allowedExtensions,
      required this.onImport,
      this.warning,
      this.multiple = false,
      this.onAllSuccess});

  Future<void> pickAndProcessFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: multiple);

    if (!multiple && result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;
      final File file = File(filePath);

      try {
        final String fileContent = await file.readAsString();
        _showImportDialog(context, fileName, fileContent);
      } catch (e) {
        Get.snackbar('文件读取错误', '$e');
      }
    } else if (multiple && result != null) {
      result.files.forEach((f) async {
        try {
          fileNames.add(f.name);
          final file = File(f.path!);
          final content = await file.readAsString();
          fileContents.add(content);
          
        } catch (e) {
          Get.snackbar('文件读取错误', '$e');
        }
      });
      _showImportDialog(context, '', '');
    } else {}
  }

  void _showImportDialog(
      BuildContext context, String fileName, String fileContent) {
    List<ImportParam> dialogParams = paramList
        .map((p) =>
            ImportParam(id: p.id, name: p.name, isSelected: p.isSelected))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title ?? '导入${fileName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!multiple)
                      Text('已选择文件:${fileName}')
                    else
                      Text('已选择的文件：${fileNames.join('\n')}'),
                    SizedBox(
                      height: 10,
                    ),
                    if (introduction != null) Text(introduction!),
                    if (warning != null)
                      ModernAlertCard(
                        child: Text(warning!),
                        type: ModernAlertCardType.warning,
                      ),
                    const SizedBox(height: 16),
                    ...dialogParams.map((param) {
                      return CheckboxListTile(
                        title: Text(param.name),
                        value: param.isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            param.isSelected = value ?? false;
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('确认'),
                  onPressed: () {
                    List<String> selectedParamIds = dialogParams
                        .where((param) => param.isSelected)
                        .map((param) => param.id)
                        .toList();

                    if (!multiple) {
                      onImport(fileName, fileContent, selectedParamIds);
                    } else {
                      for (int index = 0; index < fileNames.length; index++) {
                        final name = fileNames[index];
                        onImport(name, fileContents[index], selectedParamIds);
                      }
                      if (onAllSuccess != null) {
                        onAllSuccess!(fileName.length, selectedParamIds);
                      }
                    }

                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
