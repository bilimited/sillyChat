import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/GoogleServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/OpenAIServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';

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
    ServiceProvider.deepseek: Openaiservicehandler(
        baseUrl: 'https://api.deepseek.com',
        name: 'deepSeek',
        defaultModelList: [
          'deepseek-chat',
          'deepseek-reasoner',
          'DeepSeek-V3-0324',
          'DeepSeek-R1-0528',
          'DeepSeek-V3',
          'DeepSeek-R1'
        ]),
    ServiceProvider.siliconflow: Openaiservicehandler(
        baseUrl: 'https://api.siliconflow.cn/v1',
        name: '硅基流动',
        defaultModelList: [
          'deepseek-ai/DeepSeek-V3',
          'deepseek-ai/DeepSeek-R1',
          'Pro/deepseek-ai/DeepSeek-R1',
          'Pro/deepseek-ai/DeepSeek-V3',
          'Qwen/Qwen3-32B',
          'Qwen/Qwen3-30B-A3B',
          'Qwen/Qwen3-8B'
        ]),
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
    ServiceProvider.kimi: Openaiservicehandler(
        baseUrl: 'https://api.moonshot.cn/v1',
        name: 'Kimi',
        defaultModelList: 
      [
        
      ]
    )
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
