import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: InAppWebViewExample(),
    );
  }
}

class InAppWebViewExample extends StatefulWidget {
  const InAppWebViewExample({super.key});

  @override
  State<InAppWebViewExample> createState() => _InAppWebViewExampleState();
}

class _InAppWebViewExampleState extends State<InAppWebViewExample> {
  late InAppWebViewController _webViewController;
  String _dartVariable = "初始值";

  // HTML 内容
  final String _htmlContent = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>WebView交互示例</title>
      <style>
          body { font-family: sans-serif; text-align: center; padding: 20px; }
          button { padding: 10px 20px; font-size: 16px; margin: 10px; }
          #messageFromDart { margin-top: 20px; font-weight: bold; color: blue; }
      </style>
  </head>
  <body>
      <h1>WebView 与 Dart 交互</h1>

      <p>Dart 变量的值: <span id="dartVarDisplay">初始值</span></p>

      <button onclick="updateDartVariable()">通过JS修改Dart变量</button>
      <button onclick="callDartMethod()">通过JS调用Dart方法</button>

      <div id="messageFromDart"></div>

      <script>
          // 等待flutter_inappwebview平台准备就绪
          window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
              console.log("Flutter InAppWebView is ready!");
          });

          // 1. 通过调用JS方法修改Dart变量
          function updateDartVariable() {
              const newValue = "由JS在 " + new Date().toLocaleTimeString() + " 修改";
              window.flutter_inappwebview.callHandler('updateDartVariableHandler', newValue);
          }

          // 2. 通过JS调用Dart方法
          async function callDartMethod() {
              try {
                  const result = await window.flutter_inappwebview.callHandler('showDartAlert', '这是一个来自JS的消息！');
                  console.log("从Dart返回的数据: " + result.message);
                  alert("Dart方法执行完毕，并返回: " + result.message);
              } catch (e) {
                  console.error(e);
              }
          }

          // 供Dart调用的JS函数
          function updateTextFromDart(message, value) {
              document.getElementById('messageFromDart').innerText = message + " 值为: " + value;
          }

          // 更新显示的Dart变量的值
          function updateDartVariableDisplay(newValue) {
              document.getElementById('dartVarDisplay').innerText = newValue;
          }
      </script>
  </body>
  </html>
  """;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter InAppWebView 示例'),
      ),
      body: Column(
        children: [
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(data: _htmlContent),
              onWebViewCreated: (controller) {
                _webViewController = controller;

                // 注册一个JavaScript处理器来更新Dart变量
                _webViewController.addJavaScriptHandler(
                    handlerName: 'updateDartVariableHandler',
                    callback: (args) {
                      setState(() {
                        _dartVariable = args[0];
                      });
                      // 更新WebView中的显示
                      _webViewController.evaluateJavascript(
                          source:
                              "updateDartVariableDisplay('$_dartVariable')");
                    });

                // 注册一个JavaScript处理器来让JS调用Dart方法
                _webViewController.addJavaScriptHandler(
                    handlerName: 'showDartAlert',
                    callback: (args) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('来自JS的调用'),
                          content: Text(args[0]),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('关闭'),
                            )
                          ],
                        ),
                      );
                      // 返回数据给JavaScript
                      return {'message': '成功！'};
                    });
              },
              onConsoleMessage: (controller, consoleMessage) {
                print(consoleMessage);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Dart变量: $_dartVariable',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // 3. Dart调用JS方法并传值
                    _webViewController.evaluateJavascript(
                        source: "updateTextFromDart('来自Dart的消息', 12345)");
                  },
                  child: const Text('Dart调用JS方法并传值'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
