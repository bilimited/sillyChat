import 'package:flutter/material.dart';

class SimulateUserHelper {
  /// 显示 AI 帮答弹窗，并返回用户选择的答案
  ///
  /// [context]: 必须是有效的 BuildContext
  /// [simulateUserMessage]: 外部提供的异步方法，返回候选答案列表
  static Future<String?> showAIAssistDialog({
    required BuildContext context,
    required Future<List<String>> simulateUserMessage,
  }) async {
    final colors = Theme.of(context).colorScheme;
    // 显示加载状态的弹窗
    return await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        return SafeArea(
          child: FutureBuilder<List<String>>(
            future: simulateUserMessage,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(
                          height: 16,
                        ),
                        Text("正在加载AI帮答...")
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return Text('加载失败: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('暂无推荐内容');
              } else {
                final suggestions = snapshot.data!;
                return SizedBox(
                  height: 300, // 简单高度估算
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 16,
                          right: 16,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(dialogContext).pop(suggestions[index]);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 14.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .shadowColor
                                      .withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              suggestions[index],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
