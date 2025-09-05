import 'package:flutter/material.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  Widget build(BuildContext context) {
    // WillPopScope 阻止用户通过返回键退出
    return WillPopScope(
      onWillPop: () async {
        // 返回 false 表示阻止返回事件
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('加载中'),
          // 隐藏 AppBar 的返回按钮（如果存在）
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(), // 加载指示器
              SizedBox(height: 20), // 间距
              Text(
                '正在加载仓库', // 显示的加载文本
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
