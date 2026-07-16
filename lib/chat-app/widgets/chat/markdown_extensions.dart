import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/widgets/chat/custom_codeblock_widget.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class QuotedTextSyntax extends md.InlineSyntax {
  QuotedTextSyntax() : super(r'[“"”]([^"“”]*)["“”]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = md.Element.text('quotedText', match.group(1)!);
    parser.addNode(text);
    return true;
  }
}

class QuotedTextBuilder extends MarkdownElementBuilder {
  final TextScaler textScaler;

  // 在构造函数中接收 context
  QuotedTextBuilder(this.textScaler);

  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    if (element.tag == 'quotedText') {
      // 在这里使用 context 来获取主题颜色
      final colors = Theme.of(context).colorScheme;
      return RichText(
        textScaler: textScaler,
        text: TextSpan(
          text: '"${element.textContent}"',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return null;
  }
}

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'"([^"]*)"');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = md.Element.text('latex', match.group(1)!);
    parser.addNode(text);
    return true;
  }
}

class HtmlTagSyntax extends md.InlineSyntax {
  HtmlTagSyntax() : super(r'<([a-zA-Z0-9]+)\s*([^>]*)>(.*?)<\/\1>');

  // 正则表达式用于解析属性
  final _attributeRegex = RegExp(r'([a-zA-Z0-9_-]+)\s*=\s*('
      r'"([^"]*)"|' // 带双引号的属性值
      r"'([^']*)'|" // 带单引号的属性值
      r'([^>\s]+)' // 不带引号的属性值
      r')');

  /// 规范化颜色代码
  /// 将 #rgb, #rrggbb, #rrggbbaa 格式统一转换为 #rrggbbaaff
  String _normalizeColor(String color) {
    if (color.startsWith('#')) {
      String hex = color.substring(1);
      if (hex.length == 3) {
        // #rgb -> #rrggbb
        hex = hex.split('').map((c) => c + c).join('');
      }
      if (hex.length == 6) {
        // #rrggbb -> #rrggbbaa (默认alpha为ff)
        hex = '${hex}ff';
      }
      if (hex.length == 8) {
        return '${hex.toLowerCase()}';
      }
    }
    return color;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tagName = match.group(1)!;
    final attributesString = match.group(2) ?? '';
    final content = match.group(3) ?? '';

    final attributes = <String, String>{};
    for (final attrMatch in _attributeRegex.allMatches(attributesString)) {
      final key = attrMatch.group(1)!.toLowerCase();
      // group(3), group(4), group(5) 分别对应双引号、单引号和无引号的值
      String value =
          attrMatch.group(3) ?? attrMatch.group(4) ?? attrMatch.group(5) ?? '';

      if (key == 'color') {
        value = _normalizeColor(value);
      }
      attributes[key] = value;
    }

    final element = md.Element(tagName, [md.Text(content)]);
    element.attributes.addAll(attributes);
    parser.addNode(element);

    return true;
  }
}

class FontColorBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    if (element.tag == 'font') {
      final color = element.attributes['color'];
      return RichText(
        text: TextSpan(
          text: element.textContent,
          style: parentStyle?.copyWith(color: Color(int.parse('0x$color'))),
        ),
      );
    }
    return null;
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final TextScaler textScaler;

  // 在构造函数中接收 context
  CodeBlockBuilder(this.textScaler);

  @override
  void visitElementBefore(md.Element element) {
    if (element.tag != 'pre') return;

    // 1. 提取原始代码内容和语言
    // 我们必须在 Before 阶段做这件事，因为稍后我们要清空 children
    String codeText = '';
    String language = '';

    if (element.children != null && element.children!.isNotEmpty) {
      // FencedCodeBlock 通常结构是 <pre><code class="language-dart">...</code></pre>
      for (var child in element.children!) {
        if (child is md.Element && child.tag == 'code') {
          codeText = child.textContent;
          // 提取语言
          final classAttribute = child.attributes['class'];
          if (classAttribute != null &&
              classAttribute.startsWith('language-')) {
            language = classAttribute.substring('language-'.length);
          }
        } else if (child is md.Text) {
          // 某些特殊情况下可能有直接文本
          codeText += child.text;
        }
      }
    } else {
      codeText = element.textContent;
    }

    // 2. 将提取的数据暂存到 element 的 attributes 中
    // 这样在 visitElementAfter 中就能获取到了
    element.attributes['__custom_code__'] = codeText.trimRight();
    element.attributes['__custom_lang__'] = language;

    // 3. ★ 关键修复步骤 ★
    // 清空子元素。这样 flutter_markdown 就不会去遍历它们，
    // 就不会把代码文本添加到 _inlines 缓冲区中。
    // 当执行到 visitElementAfter 时，_inlines 也就保持为空，从而通过断言检测。
    element.children?.clear();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element.tag != 'pre') return null;

    // 4. 从 attributes 中取出我们在 Before 阶段保存的数据
    final codeText = element.attributes['__custom_code__'] ?? '';
    final language = element.attributes['__custom_lang__'] ?? '';

    return CustomCodeBlockWidget(
      code: codeText,
      language: language,
      textScaler: textScaler,
    );
  }
}
