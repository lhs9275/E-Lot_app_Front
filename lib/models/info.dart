class Info {
  final String name;
  final int age;
  final String message;

  Info({
    required this.name,
    required this.age,
    required this.message,
  });

  factory Info.fromJson(Map<String, dynamic> json) {
    return Info(
      name: json['name'] as String,
      age: json['age'] as int,
      message: json['message'] as String,
    );
  }
}