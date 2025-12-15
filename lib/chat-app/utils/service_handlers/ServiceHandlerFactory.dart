import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/DeepSeekServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/GoogleServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/KimiServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/OpenAIServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/SiliconFlowServiceHandler.dart';

class Servicehandlerfactory {
  static const providers = {
    ServiceProvider.openai: Openaiservicehandler(
        baseUrl: 'https://api.openai.com/v1',
        name: 'openAI',
        defaultModelList: [
          "gpt-3.5-turbo",
          "gpt-4",
          "gpt-4o",
        ]),
    ServiceProvider.deepseek: Deepseekservicehandler(),
    ServiceProvider.siliconflow: Siliconflowservicehandler(),
    ServiceProvider.custom_openai_compatible:
        Openaiservicehandler(baseUrl: '', name: '自定义', defaultModelList: []),
    ServiceProvider.google: Googleservicehandler(
        baseUrl: 'no need',
        name: 'google',
        defaultModelList: [
          "gemini-2.5-pro",
          "gemini-2.5-pro-preview-06-05",
          "gemini-2.5-pro-preview-05-06",
          "gemini-2.5-pro-preview-03-25",
          "gemini-2.5-pro-exp-03-25",
          "gemini-2.5-flash",
          "gemini-2.5-flash-preview-05-20",
          "gemini-2.5-flash-preview-04-17",
          "gemini-2.5-lite-preview-06-17",
          "gemini-2.0-flash",
          "gemini-2.0-flash-lite",
          "gemini-1.5-flash",
          "gemini-1.5-flash-8b",
          "gemini-1.5-pro",
          "gemini-1.0-pro"
        ]),
    ServiceProvider.kimi: Kimiservicehandler(),
  };

  static const defaultHandler = Openaiservicehandler(
      baseUrl: 'https://api.openai.com/v1',
      name: 'openAI',
      defaultModelList: [
        "gpt-3.5-turbo",
        "gpt-4",
        "gpt-4o",
      ]);

  static Servicehandler getHandler(ServiceProvider service,
      {String? customURL}) {
    if (service == ServiceProvider.custom_openai_compatible &&
        customURL != null) {
      return Openaiservicehandler(
          baseUrl: customURL, name: '自定义', defaultModelList: []);
    }
    return providers[service] ?? defaultHandler;
  }
}
