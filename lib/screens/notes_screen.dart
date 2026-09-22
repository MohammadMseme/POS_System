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
    if (!Hive.isBoxOpen('notes')) {
      _notesBox = await Hive.openBox<Note>('notes');
    } else {
      _notesBox = Hive.box<Note>('notes');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  void _showNoteDialog({
    Note? existingNote,
    int? index,
  }) {
    final titleController = TextEditingController(
      text: existingNote?.title ?? '',
    );

    final contentController = TextEditingController(
      text: existingNote?.content ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.brown.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_note,
                color: Colors.brown.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                existingNote == null
                    ? 'إضافة ملاحظة جديدة'
                    : 'تعديل الملاحظة',
                style: TextStyle(
                  color: Colors.brown.shade900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'عنوان الملاحظة',
                    prefixIcon: const Icon(
                      Icons.title,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.brown.shade700,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.brown.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: contentController,
                  maxLines: 7,
                  decoration: InputDecoration(
                    labelText: 'محتوى الملاحظة',
                    hintText:
                        'اكتب تفاصيل الملاحظة هنا...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(
                      Icons.notes_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.brown.shade300,
                      ),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.brown.shade700,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ في الدفتر'),
            onPressed: () {
              final title =
                  titleController.text.trim();
              final content =
                  contentController.text.trim();

              if (title.isEmpty && content.isEmpty) {
                return;
              }

              if (existingNote == null) {
                final newNote = Note(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  title: title.isEmpty
                      ? 'ملاحظة بدون عنوان'
                      : title,
                  content: content,
                  createdAt: DateTime.now(),
                );

                _notesBox.add(newNote);
              } else {
                existingNote.title = title.isEmpty
                    ? 'ملاحظة بدون عنوان'
                    : title;

                existingNote.content = content;

                existingNote.createdAt =
                    DateTime.now();

                existingNote.save();
              }

              setState(() {});
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.red.shade700,
            ),
            const SizedBox(width: 10),
            const Text(
              'حذف الملاحظة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذه الملاحظة نهائياً من الدفتر؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _notesBox.deleteAt(index);
              setState(() {});
              Navigator.pop(ctx);
            },
            label: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_outlined,
              size: 60,
              color: Colors.brown.shade400,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'الدفتر فارغ حالياً',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على زر الإضافة لتسجيل ملاحظتك الأولى',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.menu_book_outlined),
            SizedBox(width: 10),
            Text(
              'دفتر الملاحظات اليومي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.brown.shade700,
              ),
            )
          : ValueListenableBuilder<Box<Note>>(
              valueListenable: _notesBox.listenable(),
              builder: (
                context,
                Box<Note> box,
                _,
              ) {
                if (box.isEmpty) {
                  return _buildEmptyState();
                }

                final notes =
                    box.values.toList().reversed.toList();

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 90,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];

                      // لأن العرض معكوس، هذا هو الفهرس الحقيقي
                      // داخل Hive.
                      final realIndex =
                          box.length - 1 - index;

                      return InkWell(
                        onTap: () => _showNoteDialog(
                          existingNote: note,
                          index: realIndex,
                        ),
                        borderRadius:
                            BorderRadius.circular(15),
                        child: Container(
                          padding:
                              const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius:
                                BorderRadius.circular(15),
                            border: Border.all(
                              color:
                                  Colors.amber.shade300,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey
                                    .withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 7,
                                offset:
                                    const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.all(
                                      7,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: Colors
                                          .brown.shade100,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        8,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.note_outlined,
                                      size: 18,
                                      color: Colors
                                          .brown.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors
                                            .brown.shade900,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف الملاحظة',
                                    icon: const Icon(
                                      Icons
                                          .delete_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: () =>
                                        _deleteNote(
                                      realIndex,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Divider(
                                color:
                                    Colors.amber.shade400,
                              ),

                              const SizedBox(height: 4),

                              Expanded(
                                child: Text(
                                  note.content.isEmpty
                                      ? 'لا يوجد محتوى'
                                      : note.content,
                                  style: TextStyle(
                                    color: Colors
                                        .brown.shade800,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                  maxLines: 6,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .schedule_outlined,
                                    size: 14,
                                    color: Colors
                                        .brown.shade600,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors
                                          .brown.shade600,
                                    ),
                                  ),
                                ],
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

      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () => _showNoteDialog(),
        tooltip: 'إضافة ملاحظة جديدة',
        icon: const Icon(Icons.add),
        label: const Text(
          'ملاحظة جديدة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

