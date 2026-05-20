class CategoryConfig {
  String name;
  int order;

  CategoryConfig({required this.name, required this.order});

  factory CategoryConfig.fromJson(Map<String, dynamic> json) {
    return CategoryConfig(
      name: json['name'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'order': order,
      };
}
