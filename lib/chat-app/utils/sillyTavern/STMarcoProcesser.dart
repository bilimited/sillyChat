import 'dart:math';

/// SillyTavern 宏处理器类
class STMacroProcessor {
  /// 兼容SillyTavern宏
  /// 对传入Prompt进行正则匹配
  /// 如：若匹配到{{setvar::wordsCloud::1100}} 代表将varibles中的wordCloud设为1100，并将匹配的字符串从prompt删除
  /// 匹配到{{getvar::wordsCloud}}则将其替换为varible中的wordCloud变量或空字符串
  /// 匹配到{{random::a,b,c,d...}}则将其替换为a,b,c,d...中的随机一个项
  /// 匹配到{{roll 1d999}}则替换为一个1到999直接的随机整数（投掷1个999面骰子）
  static String handleSTMacro(String prompt, Map<String, String> varibles) {
    String currentPrompt = prompt;

    // 1. 处理 setvar 宏，它们会修改变量并从字符串中移除
    currentPrompt = _handleSetVar(currentPrompt, varibles);
    currentPrompt = _handleAddVar(currentPrompt, varibles);

    // 2. 处理替换型宏
    // 可以循环处理，直到没有宏可以被替换，以处理宏嵌套的情况
    int loopLimit = 10; // 添加一个循环限制，防止因错误或复杂嵌套导致的无限循环
    while (loopLimit-- > 0) {
      String previousPrompt = currentPrompt;
      currentPrompt = _handleGetVar(currentPrompt, varibles);
      currentPrompt = _handleRandom(currentPrompt);
      currentPrompt = _handleRoll(currentPrompt);

      // 如果一轮处理后字符串没有变化，说明没有更多宏了，可以退出循环
      if (previousPrompt == currentPrompt) {
        break;
      }
    }

    return currentPrompt;
  }

  /// 处理 {{setvar::key::value}}
  /// 这个函数会持续查找并处理所有 setvar 宏，直到找不全为止
  static String _handleSetVar(String prompt, Map<String, String> varibles) {
    // 正则表达式匹配 {{setvar::key::value}}
    final regex = RegExp(r'\{\{setvar::(.*?)::(.*?)\}\}');
    String currentPrompt = prompt;

    // 使用 while 循环，因为 replaceFirst 只替换第一个匹配项
    // 每次替换后，都需要重新从头开始搜索
    while (regex.hasMatch(currentPrompt)) {
      final match = regex.firstMatch(currentPrompt);
      if (match != null) {
        final key = match.group(1);
        final value = match.group(2);
        final fullMatch = match.group(0);

        if (key != null && value != null && fullMatch != null) {
          // 设置变量
          varibles[key] = value;
          // 从 prompt 中删除该宏字符串
          currentPrompt = currentPrompt.replaceFirst(fullMatch, '');
        }
      }
    }
    return currentPrompt;
  }

  /// 处理 {{addvar::key::value}}
  /// 如果变量不存在，则添加；如果已存在，则忽略。
  /// 这个函数会持续查找并处理所有 addvar 宏，直到找不全为止
  static String _handleAddVar(String prompt, Map<String, String> vars) {
    // 正则表达式匹配 {{addvar::key::value}}
    final regex = RegExp(r'\{\{addvar::(.*?)::(.*?)\}\}');
    String currentPrompt = prompt;

    while (regex.hasMatch(currentPrompt)) {
      final match = regex.firstMatch(currentPrompt);
      if (match != null) {
        final key = match.group(1);
        final value = match.group(2);
        final fullMatch = match.group(0);

        if (key != null && value != null && fullMatch != null) {
          // 检查变量是否已存在，如果不存在则添加
          if (!vars.containsKey(key)) {
            vars[key] = value;
          }
          // 从 prompt 中删除该宏字符串
          currentPrompt = currentPrompt.replaceFirst(fullMatch, '');
        }
      }
    }
    return currentPrompt;
  }

  /// 处理 {{getvar::key}}
  static String _handleGetVar(String prompt, Map<String, String> varibles) {
    // 正则表达式匹配 {{getvar::key}}
    final regex = RegExp(r'\{\{getvar::(.*?)\}\}');
    return prompt.replaceAllMapped(regex, (match) {
      final key = match.group(1);
      if (key != null) {
        // 返回变量值，如果变量不存在，则返回空字符串
        return varibles[key] ?? '';
      }
      return '';
    });
  }

  /// 处理 {{random::a,b,c,...}}
  static String _handleRandom(String prompt) {
    // 正则表达式匹配 {{random::item1,item2,...}}
    final regex = RegExp(r'\{\{random::(.*?)\}\}');
    final random = Random();

    return prompt.replaceAllMapped(regex, (match) {
      final itemsString = match.group(1);
      if (itemsString != null && itemsString.isNotEmpty) {
        final items = itemsString.split(',');
        if (items.isNotEmpty) {
          // 随机选择列表中的一个项并返回
          final randomIndex = random.nextInt(items.length);
          return items[randomIndex].trim(); // trim() 用于去除可能存在的前后空格
        }
      }
      // 如果没有可选项，返回空字符串
      return '';
    });
  }

  /// 处理 {{roll XdY}}
  static String _handleRoll(String prompt) {
    // 正则表达式匹配 {{roll 1d999}} 或 {{roll 2d6}} 等
    // \s+ 匹配一个或多个空白字符
    // (\d+) 捕获一个或多个数字
    final regex = RegExp(r'\{\{roll\s+(\d+)d(\d+)\}\}');
    final random = Random();

    return prompt.replaceAllMapped(regex, (match) {
      try {
        final numDice = int.parse(match.group(1)!);
        final numFaces = int.parse(match.group(2)!);

        if (numDice <= 0 || numFaces <= 0) {
          return '0'; // 骰子数或面数无效，返回0
        }

        int total = 0;
        for (int i = 0; i < numDice; i++) {
          // random.nextInt(n) 生成 0 到 n-1 的整数，所以需要 +1
          total += random.nextInt(numFaces) + 1;
        }
        return total.toString();
      } catch (e) {
        // 如果解析数字失败，返回原始匹配项或空字符串
        return match.group(0)!;
      }
    });
  }
}
