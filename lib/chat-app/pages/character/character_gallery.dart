import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CharacterGalleryPage extends StatefulWidget {
  final String path;

  const CharacterGalleryPage({
    super.key,
    required this.path,
  });

  @override
  State<CharacterGalleryPage> createState() => _CharacterGalleryPageState();
}

class _CharacterGalleryPageState extends State<CharacterGalleryPage> {
  // 存储特定路径下的图片文件列表
  List<File> _images = [];
  // 存储被选中图片的路径（用于多选模式）
  final Set<String> _selectedPaths = {};
  // 是否处于选择模式
  bool _isSelectionMode = false;
  // 我们的特定相册目录
  Directory? _galleryDir;

  @override
  void initState() {
    super.initState();
    _initGalleryDir();
  }

  /// 1. 初始化并创建特定目录
  Future<void> _initGalleryDir() async {
    final dir = Directory(widget.path);

    if (!await dir.exists()) {
      await dir.create();
    }

    setState(() {
      _galleryDir = dir;
    });
    _loadImages();
  }

  /// 2. 加载目录下的所有 jpg/png 图片
  Future<void> _loadImages() async {
    if (_galleryDir == null) return;

    final List<FileSystemEntity> entities = _galleryDir!.listSync();
    final List<File> imageFiles = entities.whereType<File>().where((file) {
      final ext = path.extension(file.path).toLowerCase();
      return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';
    }).toList();

    // 按修改时间倒序排列（新的在前面）
    imageFiles
        .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      _images = imageFiles;
    });
  }

  /// 3. 从系统相册选择并复制图片
  Future<void> _pickAndCopyImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && _galleryDir != null) {
      final String fileName = path.basename(pickedFile.path);
      final String newPath = path.join(_galleryDir!.path, fileName);

      // 复制文件到我们的特定目录
      await File(pickedFile.path).copy(newPath);

      // 刷新列表
      _loadImages();
    }
  }

  /// 4. 切换多选模式状态
  void _toggleSelection(String filePath) {
    setState(() {
      if (_selectedPaths.contains(filePath)) {
        _selectedPaths.remove(filePath);
        // 如果取消选中最后一个，退出选择模式
        if (_selectedPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPaths.add(filePath);
      }
    });
  }

  /// 5. 批量删除
  Future<void> _deleteSelected() async {
    for (var filePath in _selectedPaths) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _exitSelectionMode();
    _loadImages();
  }

  /// 6. 重命名 (仅当选中一张时)
  Future<void> _renameSelected(BuildContext context) async {
    if (_selectedPaths.length != 1) return;

    final String currentPath = _selectedPaths.first;
    final File originalFile = File(currentPath);
    final String oldName = path.basename(currentPath);
    final String ext = path.extension(currentPath);
    final TextEditingController controller =
        TextEditingController(text: path.basenameWithoutExtension(currentPath));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("重命名"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "新文件名"),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final String newPath =
                    path.join(originalFile.parent.path, "$newName$ext");
                await originalFile.rename(newPath);
                Navigator.pop(ctx);
                _exitSelectionMode();
                _loadImages();
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPaths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? "已选择 ${_selectedPaths.length} 项" : "画廊"),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            // 重命名按钮：仅当选中1张时显示
            if (_selectedPaths.length == 1)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: "重命名",
                onPressed: () => _renameSelected(context),
              ),
            // 删除按钮
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: "删除",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("确认删除"),
                    content: Text("确定要删除这 ${_selectedPaths.length} 张照片吗？"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("取消")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteSelected();
                        },
                        child: const Text("删除",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]
        ],
      ),
      body: _images.isEmpty
          ? Center(
              child: Text("暂无照片，点击 + 添加", style: theme.textTheme.bodyLarge))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              // 瀑布流布局核心
              child: MasonryGridView.count(
                crossAxisCount: 2, // 列数
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final file = _images[index];
                  final isSelected = _selectedPaths.contains(file.path);

                  return GestureDetector(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(file.path);
                      } else {
                        // 查看大图
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    FullScreenImagePage(file: file)));
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                        });
                        _toggleSelection(file.path);
                      }
                    },
                    child: Stack(
                      children: [
                        // 图片卡片
                        Hero(
                          tag: file.path, // 用于大图转场动画
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              // 优化：列表页不需要加载原图大小，设置缓存宽度提升性能
                              cacheWidth: 400,
                            ),
                          ),
                        ),
                        // 选中状态遮罩层
                        if (_isSelectionMode)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.primaryColor.withOpacity(0.4)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: theme.primaryColor, width: 3)
                                    : null,
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(Icons.check_circle,
                                          color: Colors.white, size: 48))
                                  : const Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.circle_outlined,
                                            color: Colors.white),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      // 选择模式下隐藏加号按钮
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _pickAndCopyImage,
              backgroundColor: theme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }
}

/// 简单的大图查看页面
class FullScreenImagePage extends StatelessWidget {
  final File file;

  const FullScreenImagePage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        // InteractiveViewer 支持双指缩放
        child: InteractiveViewer(
          child: Hero(
            tag: file.path,
            child: Image.file(file),
          ),
        ),
      ),
    );
  }
}
