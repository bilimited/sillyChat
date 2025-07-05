import 'package:flutter_example/chat-app/models/api_model.dart';

class VaultSettings {
  final String vaultName;
  final DateTime? lastSyncTime;
  final List<ApiModel> apis;
  final int myId;

  VaultSettings({
    required this.vaultName,
    this.lastSyncTime,
    required this.apis,
    this.myId = 0,
  });

  Map<String, dynamic> toJson() => {
    'vaultName': vaultName,
    'lastSyncTime': lastSyncTime?.toIso8601String(),
    'apis': apis.map((api) => api.toJson()).toList(),
    'myId': myId
  };

  factory VaultSettings.fromJson(Map<String, dynamic> json) {
    return VaultSettings(
      vaultName: json['vaultName'] ?? '',
      lastSyncTime: json['lastSyncTime'] != null 
          ? DateTime.parse(json['lastSyncTime'])
          : null,
      apis: (json['apis'] as List<dynamic>)
          .map((item) => ApiModel.fromJson(item))
          .toList(),
      myId: (json['myId']?? 0)
    );
  }
}
