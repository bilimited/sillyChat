// 定义回调函数的类型签名
import 'package:flutter/material.dart';

typedef OnCrumbTap = void Function(String path);

/// 一个可配置的面包屑导航组件
class BreadcrumbNavigation extends StatelessWidget {
  /// 当前的完整路径, e.g., "a/b/c/d"
  final String path;

  /// 根路径, e.g., "a/b"
  final String basePath;

  /// 点击面包屑项时的回调函数
  final OnCrumbTap onCrumbTap;

  /// 自定义根路径的显示名称
  final String rootLabel;

  /// 自定义分隔符
  final Widget separator;

  /// 自定义文本样式
  final TextStyle? style;

  /// 自定义激活状态的文本样式（最后一个面包屑）
  final TextStyle? activeStyle;

  /// 最多显示的面包屑层级数
  final int maxLevels;

  const BreadcrumbNavigation({
    Key? key,
    required this.path,
    required this.basePath,
    required this.onCrumbTap,
    this.rootLabel = '根路径', // 默认显示为 "根路径"
    this.separator = const Icon(Icons.chevron_right, size: 18.0),
    this.style,
    this.activeStyle,
    this.maxLevels = 3, // 默认最多显示3级
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // _buildCrumbs 方法负责解析路径并返回面包屑数据列表
    final items = _buildCrumbs();

    // 如果没有可显示的面包屑，则返回一个空容器
    if (items.isEmpty) {
      return Container();
    }

    // 使用 ListView 或 SingleChildScrollView 来防止内容溢出
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isEven) {
            // 偶数索引是面包屑项
            final itemIndex = index ~/ 2;
            final item = items[itemIndex];
            final isLast = itemIndex == items.length - 1;

            return _buildCrumbItem(item, isLast);
          } else {
            // 奇数索引是分隔符
            return separator;
          }
        }),
      ),
    );
  }

  /// 构建单个面包屑项
  Widget _buildCrumbItem(_BreadcrumbItem item, bool isLast) {
    // 最后一个面包屑项通常是当前页面，可以设置为不可点击或有不同样式
    return InkWell(
      onTap: isLast ? null : () => onCrumbTap(item.path),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          item.label,
          style: isLast
              ? activeStyle ?? style?.copyWith(fontWeight: FontWeight.bold)
              : style,
        ),
      ),
    );
  }

  /// 解析路径并生成面包屑数据
  List<_BreadcrumbItem> _buildCrumbs() {
    // 检查路径是否合法
    if (!path.startsWith(basePath)) {
      // 如果当前路径不在根路径下，不显示面包屑
      return [];
    }

    final List<_BreadcrumbItem> items = [];

    // 1. 添加根路径面包屑
    items.add(_BreadcrumbItem(label: rootLabel, path: basePath));

    // 2. 处理剩余路径
    // e.g., path="a/b/c/d", basePath="a/b" -> remaining="c/d"
    String remainingPath = path.substring(basePath.length);
    if (remainingPath.startsWith('/')) {
      remainingPath = remainingPath.substring(1);
    }

    // 如果没有剩余路径，直接返回根路径
    if (remainingPath.isEmpty) {
      return items;
    }

    final segments = remainingPath.split('/');

    // 3. 逐级生成面包屑项
    String currentPath = basePath;
    for (final segment in segments) {
      currentPath = '$currentPath/$segment';
      items.add(_BreadcrumbItem(label: segment, path: currentPath));
    }

    // 4. 根据 maxLevels 截取末尾的N个面包屑
    if (items.length > maxLevels) {
      return items.sublist(items.length - maxLevels);
    }

    return items;
  }
}

/// 用于存储每个面包屑项的数据模型
class _BreadcrumbItem {
  final String label;
  final String path;

  _BreadcrumbItem({required this.label, required this.path});
}
