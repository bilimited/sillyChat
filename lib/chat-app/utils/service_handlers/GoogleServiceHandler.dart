
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';

class Googleservicehandler extends Servicehandler {
  Googleservicehandler({required super.baseUrl, required super.name, required super.defaultModelList});

  @override
  Future<List<String>> fetchModelList() {
    // TODO: implement fetchModelList
    throw UnimplementedError();
  }

  @override
  parseMessage(LLMMessage) {
    // TODO: implement parseMessage
    throw UnimplementedError();
  }

  @override
  Stream<String> request(LLMRequestOptions options, ApiModel api) {
    // TODO: implement request
    throw UnimplementedError();
  }


}