import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/GoogleServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/OpenAIServiceHandler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';

class Servicehandlerfactory {
  static const openAI =
      Openaiservicehandler(baseUrl: '  ', name: 'name', defaultModelList: []);

  static const google = Googleservicehandler(
      baseUrl: 'baseUrl', name: 'name', defaultModelList: []);

  static Servicehandler getHandler(ServiceProvider service) {
    if ([
      ServiceProvider.openai,
      ServiceProvider.deepseek,
      ServiceProvider.siliconflow,
      ServiceProvider.custom_openai_compatible
    ].contains(service)) {
      return openAI;
    } else if (ServiceProvider.google == service) {
      return google;
    }

    return openAI;
  }
}
