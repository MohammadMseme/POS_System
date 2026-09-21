import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Box<Note> _notesBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _openNotesBox();
  }

  Future<void> _openNotesBox() async {
    // التأكد من فتح صندوق الملاحظات (تأكد من فتح الـ Box مسبقاً في الـ main أو فتحه هنا)
    if (!Hive.isBoxOpen('notes')) {
      _notesBox = await Hive.openBox<Note>('notes');
    } else {
      _notesBox = Hive.box<Note>('notes');
    }
    setState(() {
      _isLoading = false;
    });
  }

  // دالة لإضافة أو تعديل ملاحظة عبر نافذة منبثقة تشبه صفحة الدفتر
  void _showNoteDialog({Note? existingNote, int? index}) {
    final titleController = TextEditingController(text: existingNote?.title ?? '');
    final contentController = TextEditingController(text: existingNote?.content ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.amber.shade50, // لون قريب من ورق الدفتر المصفّر
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.brown.shade700),
            const SizedBox(width: 8),
            Text(
              existingNote == null ? 'إضافة ملاحظة جديدة للدفتر' : 'تعديل الملاحظة',
              style: TextStyle(color: Colors.brown.shade900, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان الملاحظة',
                  labelStyle: TextStyle(color: Colors.brown.shade700),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.brown.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'اكتب تفاصيل الملاحظة هنا...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.brown.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.brown.shade700, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (title.isEmpty && content.isEmpty) return;

              if (existingNote == null) {
                // إضافة ملاحظة جديدة
                final newNote = Note(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title.isEmpty ? 'ملاحظة بدون عنوان' : title,
                  content: content,
                  createdAt: DateTime.now(),
                );
                _notesBox.add(newNote);
              } else {
                // تحديث ملاحظة قائمة
                existingNote.title = title.isEmpty ? 'ملاحظة بدون عنوان' : title;
                existingNote.content = content;
                existingNote.createdAt = DateTime.now(); // تحديث وقت التعديل
                existingNote.save();
              }

              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('حفظ في الدفتر'),
          ),
        ],
      ),
    );
  }

  // دالة لحذف ملاحظة
  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملاحظة'),
        content: const Text('هل أنت متأكد من حذف هذه الملاحظة نهائياً من الدفتر؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _notesBox.deleteAt(index);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دفتر الملاحظات اليومي'),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
              valueListenable: _notesBox.listenable(),
              builder: (context, Box<Note> box, _) {
                final notes = box.values.toList().reversed.toList(); // عرض أحدث الملاحظات أولاً

                if (notes.isEmpty) {
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('الدفتر فارغ حالياً! اضغط على زر الإضافة لتسجيل ملاحظاتك.',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      // حساب الفهرس الحقيقي للحذف والتعديل لأن القائمة معكوسة
                      final realIndex = box.values.toList().indexOf(note); 

                      return InkWell(
                        onTap: () => _showNoteDialog(existingNote: note, index: realIndex),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100, // مظهر ورقة الملاحظات
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.brown.shade900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteNote(realIndex),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.amber),
                              Expanded(
                                child: Text(
                                  note.content,
                                  style: TextStyle(color: Colors.brown.shade800, fontSize: 13),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                                style: TextStyle(fontSize: 10, color: Colors.brown.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        onPressed: () => _showNoteDialog(),
        tooltip: 'إضافة ملاحظة جديدة',
        child: const Icon(Icons.add),
      ),
    );
  }
}