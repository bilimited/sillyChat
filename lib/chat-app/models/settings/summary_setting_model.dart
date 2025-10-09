import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';

class SummarySettingModel {
  final ChatOptionModel summaryOption;

  SummarySettingModel({required this.summaryOption});

  factory SummarySettingModel.defaultOption() {
    return SummarySettingModel(
        summaryOption: ChatOptionModel(
            id: 0,
            name: '总结',
            requestOptions: LLMRequestOptions(messages: []),
            prompts: [],
            regex: []));
  }
}
