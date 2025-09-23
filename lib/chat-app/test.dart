import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/widgets/BreadcrumbNavigation.dart';
// 假设上面的组件代码保存在这个文件中

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breadcrumb Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16)),
      ),
      home: const BreadcrumbDemoPage(),
    );
  }
}

class BreadcrumbDemoPage extends StatefulWidget {
  const BreadcrumbDemoPage({Key? key}) : super(key: key);

  @override
  State<BreadcrumbDemoPage> createState() => _BreadcrumbDemoPageState();
}

class _BreadcrumbDemoPageState extends State<BreadcrumbDemoPage> {
  // 定义根路径
  final String _basePath = 'a/b';
  // 当前路径，会动态变化
  String _currentPath = 'a/b/c/d/e';

  void _updatePath(String newPath) {
    setState(() {
      _currentPath = newPath;
    });
    // 在实际应用中，这里可能会触发真正的页面导航
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('导航到: $newPath'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breadcrumb Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 使用面包屑组件
            BreadcrumbNavigation(
              path: _currentPath,
              basePath: _basePath,
              onCrumbTap: _updatePath, // 传入回调函数
              // 自定义样式 (可选)
              style: TextStyle(color: Colors.blue.shade700, fontSize: 16),
              activeStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(height: 40),
            Text('当前完整路径: $_currentPath',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 用于模拟导航的按钮
            const Text('模拟导航:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: () => _updatePath('a/b'),
                  child: const Text('跳转到 根路径'),
                ),
                ElevatedButton(
                  onPressed: () => _updatePath('a/b/c'),
                  child: const Text('跳转到 c'),
                ),
                ElevatedButton(
                  onPressed: () => _updatePath('a/b/c/d'),
                  child: const Text('跳转到 d'),
                ),
                ElevatedButton(
                  onPressed: () => _updatePath('a/b/c/d/e'),
                  child: const Text('跳转到 e (超过3级)'),
                ),
                ElevatedButton(
                  onPressed: () => _updatePath('a/b/c/d/e/f'),
                  child: const Text('跳转到 f (超过3级)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
