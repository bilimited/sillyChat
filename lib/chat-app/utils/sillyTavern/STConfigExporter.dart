import 'dart:convert';

import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';

abstract class STConfigExporter {
  static const _nonMarkerSlots = [
    'main',
    'nsfw',
    'jailbreak',
    'enhanceDefinitions',
  ];

  static const _markerIdentifiers = {
    'dialogueExamples',
    'chatHistory',
    'worldInfoAfter',
    'worldInfoBefore',
    'charDescription',
    'charPersonality',
    'scenario',
    'personaDescription',
  };

  /// 将 ChatOptionModel 导出为 SillyTavern 兼容的预设 JSON 字符串
  static String export(ChatOptionModel model) {
    final json = toJson(model);
    return const JsonEncoder.withIndent('    ').convert(json);
  }

  static Map<String, dynamic> toJson(ChatOptionModel model) {
    final ro = model.requestOptions;
    final usedIdentifiers = <String>{};
    final entries = <_StPromptEntry>[];
    int nonMarkerIdx = 0;

    for (final prompt in model.prompts) {
      final identifier = _classifyPrompt(prompt);
      String? resolvedId;
      bool isMarker;

      if (identifier != null && !usedIdentifiers.contains(identifier)) {
        resolvedId = identifier;
        isMarker = _markerIdentifiers.contains(identifier);
      } else if (identifier != null && usedIdentifiers.contains(identifier)) {
        // 已使用过的marker，分配到非marker槽位
        if (nonMarkerIdx < _nonMarkerSlots.length) {
          resolvedId = _nonMarkerSlots[nonMarkerIdx++];
        }
        isMarker = false;
      } else {
        // 未匹配，分配到非marker槽位
        if (nonMarkerIdx < _nonMarkerSlots.length) {
          resolvedId = _nonMarkerSlots[nonMarkerIdx++];
        }
        isMarker = false;
      }

      if (resolvedId != null) {
        usedIdentifiers.add(resolvedId);
        entries.add(_StPromptEntry(
          identifier: resolvedId,
          prompt: prompt,
          isMarker: isMarker,
        ));
      }
    }

    // 填充未使用的marker标识符（使用模板默认值，默认禁用）
    for (final id in _markerIdentifiers) {
      if (!usedIdentifiers.contains(id)) {
        entries.add(_StPromptEntry(
          identifier: id,
          prompt: PromptModel(
            id: 0,
            content: '',
            role: 'system',
            name: _markerNames[id] ?? id,
          )..isEnable = false,
          isMarker: true,
        ));
        usedIdentifiers.add(id);
      }
    }

    // 填充未使用的非marker标识符
    for (final id in _nonMarkerSlots) {
      if (!usedIdentifiers.contains(id)) {
        entries.add(_StPromptEntry(
          identifier: id,
          prompt: PromptModel(
            id: 0,
            content: _nonMarkerDefaults[id] ?? '',
            role: 'system',
            name: _nonMarkerNames[id] ?? id,
          )..isEnable = false,
          isMarker: false,
        ));
      }
    }

    final stPrompts = <Map<String, dynamic>>[];
    for (final entry in entries) {
      stPrompts.add(_buildStPrompt(entry));
    }

    final groupOrder = <Map<String, dynamic>>[];
    final privateOrder = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final item = {
        'identifier': entry.identifier,
        'enabled': entry.prompt.isEnable,
      };
      privateOrder.add(item);
      if (entry.identifier != 'personaDescription') {
        groupOrder.add(item);
      }
    }

    return {
      'windowai_model': '',
      'temperature': ro.temperature,
      'frequency_penalty': ro.frequencyPenalty,
      'presence_penalty': ro.presencePenalty,
      'top_p': ro.topP,
      'top_k': 0,
      'top_a': 0,
      'min_p': 0,
      'repetition_penalty': 1,
      'openai_max_context': 4095,
      'openai_max_tokens': ro.maxTokens,
      'wrap_in_quotes': false,
      'names_behavior': 0,
      'send_if_empty': '',
      'impersonation_prompt':
          '[Write your next reply from the point of view of {{user}}, using the chat history so far as a guideline for the writing style of {{user}}. Don\'t write as {{char}} or system. Don\'t describe actions of {{char}}.]',
      'new_chat_prompt': '[Start a new Chat]',
      'new_group_chat_prompt':
          '[Start a new group chat. Group members: {{group}}]',
      'new_example_chat_prompt': '[Example Chat]',
      'continue_nudge_prompt':
          '[Continue your last message without repeating its original content.]',
      'bias_preset_selected': 'Default (none)',
      'max_context_unlocked': false,
      'wi_format': '{0}',
      'scenario_format': '{{scenario}}',
      'personality_format': '{{personality}}',
      'group_nudge_prompt': '[Write the next reply only as {{char}}.]',
      'stream_openai': ro.isStreaming,
      'api_url_scale': '',
      'assistant_prefill': '',
      'assistant_impersonation': '',
      'claude_use_sysprompt': false,
      'use_alt_scale': false,
      'squash_system_messages': false,
      'image_inlining': false,
      'continue_prefill': false,
      'continue_postfix': ' ',
      'seed': ro.seed,
      'n': 1,
      'prompts': stPrompts,
      'prompt_order': [
        {'character_id': 100000, 'order': groupOrder},
        {'character_id': 100001, 'order': privateOrder},
      ],
    };
  }

  /// 尝试将 SillyChat PromptModel 分类为 ST 标识符，返回 null 表示无法分类
  static String? _classifyPrompt(PromptModel prompt) {
    if (prompt.isChatHistory) return 'chatHistory';

    final content = prompt.content;

    // 精确匹配（直接对应 ST marker）
    if (content == '{{lore before_char}}') return 'worldInfoBefore';
    if (content == '{{lore after_char}}') return 'worldInfoAfter';

    // dialogueExamples: 含有示例对话相关的宏
    if (content.contains('{{dialogueExamples}}')) return 'dialogueExamples';
    if (content.contains('{{lore before_em}}') &&
        content.contains('{{lore after_em}}')) {
      return 'dialogueExamples';
    }

    // personaDescription: 用户设定
    if (content.contains('{{user}}') && content.contains('{{userbrief}}')) {
      return 'personaDescription';
    }

    // charDescription: 角色定义
    if (content.contains('{{archive}}')) return 'charDescription';
    if (content.contains('名称') &&
        content.contains('{{char}}') &&
        !content.contains('{{user}}')) {
      return 'charDescription';
    }

    // scenario: 作者注释/场景描述
    if (content.contains('{{description}}')) return 'scenario';

    // 非marker的通用提示词，不在这里匹配
    return null;
  } 

  static Map<String, dynamic> _buildStPrompt(_StPromptEntry entry) {
    if (entry.isMarker) {
      return {
        'identifier': entry.identifier,
        'name': _markerNames[entry.identifier] ?? entry.prompt.name,
        'system_prompt': true,
        'marker': true,
      };
    } else {
      return {
        'identifier': entry.identifier,
        'name': _nonMarkerNames[entry.identifier] ?? entry.prompt.name,
        'system_prompt': true,
        'role': entry.prompt.role.isNotEmpty ? entry.prompt.role : 'system',
        'content': entry.prompt.content,
        'marker': false,
      };
    }
  }

  static const _markerNames = {
    'dialogueExamples': 'Chat Examples',
    'chatHistory': 'Chat History',
    'worldInfoAfter': 'World Info (after)',
    'worldInfoBefore': 'World Info (before)',
    'charDescription': 'Char Description',
    'charPersonality': 'Char Personality',
    'scenario': 'Scenario',
    'personaDescription': 'Persona Description',
  };

  static const _nonMarkerNames = {
    'main': 'Main Prompt',
    'nsfw': 'Auxiliary Prompt',
    'jailbreak': 'Post-History Instructions',
    'enhanceDefinitions': 'Enhance Definitions',
  };

  static const _nonMarkerDefaults = {
    'main': 'Write {{char}}\'s next reply in a fictional chat between {{char}} and {{user}}.',
    'nsfw': '',
    'jailbreak': '',
    'enhanceDefinitions':
        'If you have more knowledge of {{char}}, add to the character\'s lore and personality to enhance them but keep the Character Sheet\'s definitions absolute.',
  };
}

class _StPromptEntry {
  final String identifier;
  final PromptModel prompt;
  final bool isMarker;

  _StPromptEntry({
    required this.identifier,
    required this.prompt,
    required this.isMarker,
  });
}
