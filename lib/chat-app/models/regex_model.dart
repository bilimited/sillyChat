class RegexModel {
  int id;
  String name;
  String pattern; // 正则表达式
  String replacement; // 替换文本
  int scope; // 作用范围（位掩码）
  int timing; // 作用时刻（位掩码）
  bool enabled;

  RegexModel({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.scope = 0,
    this.timing = 0,
    this.enabled = true,
  });

  // 作用范围位掩码
  static const int scopeUserInput = 1 << 0; // 用户输入
  static const int scopeAIOutput = 1 << 1;  // AI输出

  // 作用时刻位掩码
  static const int timingSendToAI = 1 << 0; // 发送给AI时
  static const int timingSave = 1 << 1;     // 保存时
  static const int timingRender = 1 << 2;   // 渲染时

  // 作用范围 getter/setter
  bool get applyToUserInput => (scope & scopeUserInput) != 0;
  set applyToUserInput(bool value) {
    if (value) {
      scope |= scopeUserInput;
    } else {
      scope &= ~scopeUserInput;
    }
  }

  bool get applyToAIOutput => (scope & scopeAIOutput) != 0;
  set applyToAIOutput(bool value) {
    if (value) {
      scope |= scopeAIOutput;
    } else {
      scope &= ~scopeAIOutput;
    }
  }

  // 作用时刻 getter/setter
  bool get applyOnSendToAI => (timing & timingSendToAI) != 0;
  set applyOnSendToAI(bool value) {
    if (value) {
      timing |= timingSendToAI;
    } else {
      timing &= ~timingSendToAI;
    }
  }

  bool get applyOnSave => (timing & timingSave) != 0;
  set applyOnSave(bool value) {
    if (value) {
      timing |= timingSave;
    } else {
      timing &= ~timingSave;
    }
  }

  bool get applyOnRender => (timing & timingRender) != 0;
  set applyOnRender(bool value) {
    if (value) {
      timing |= timingRender;
    } else {
      timing &= ~timingRender;
    }
  }

  // 序列化
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'scope': scope,
      'timing': timing,
      'enabled': enabled,
    };
  }

  // 反序列化
  factory RegexModel.fromJson(Map<String, dynamic> json) {
    return RegexModel(
      id: json['id'],
      name: json['name'],
      pattern: json['pattern'],
      replacement: json['replacement'],
      scope: json['scope'] ?? 0,
      timing: json['timing'] ?? 0,
      enabled: json['enabled'] ?? true,
    );
  }

  // 拷贝方法
  RegexModel copy() {
    return RegexModel(
      id: id,
      name: name,
      pattern: pattern,
      replacement: replacement,
      scope: scope,
      timing: timing,
      enabled: enabled,
    );
  }
}
