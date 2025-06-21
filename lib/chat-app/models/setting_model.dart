
class ValutSettingModel {

  String storagePath;
  String vaultName;
  bool isDarkMode;

  // 构造函数
  ValutSettingModel({
    required this.storagePath,
    required this.vaultName,
    required this.isDarkMode,
  });

  // 从JSON构造
  factory ValutSettingModel.fromJson(Map<String, dynamic> json) {
    return ValutSettingModel(
      storagePath: json['storage_path'] as String,
      vaultName: json['vault_name'] as String,
      isDarkMode: json['is_dark_mode'] as bool,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() => {
    'storage_path': storagePath,
    'vault_name': vaultName,
    'is_dark_mode': isDarkMode,
  };

  // 创建默认设置的工厂构造函数
  factory ValutSettingModel.defaultSettings() {
    return ValutSettingModel(
      storagePath: '',
      vaultName: 'default_vault',
      isDarkMode: false,
    );
  }
}