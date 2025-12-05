class TokenCalc {
  static int estimateTokens(String text) {
    int tokenCount = 0;
    // 简单的遍历，性能极高，可在 UI 线程直接跑
    for (int i = 0; i < text.length; i++) {
      // 判断是否为汉字 (简单判断范围)
      if (text.codeUnitAt(i) > 255) {
        tokenCount += 2; // 汉字粗略按2算（有的模型接近1）
      } else {
        tokenCount += 1; // 英文标点粗略按1算（实际上英文是0.25左右，这里需要根据平均词长调整逻辑）
      }
    }
    return (tokenCount * 0.6).round(); // 根据实际模型微调系数
  }
}
