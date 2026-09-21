import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 6) // تأكد من عدم تكرار الـ typeId مع النماذج الأخرى في مشروعك
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });
}