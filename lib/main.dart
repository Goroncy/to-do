import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: NotesScreen());
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> notes = [];

  Set<int> selectedNotes = {};
  bool isSelectionMode = false;

  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) selectedNotes.clear();
    });
  }

  void toggleNoteSelection(int index) {
    setState(() {
      if (selectedNotes.contains(index)) {
        selectedNotes.remove(index);
      } else {
        selectedNotes.add(index);
      }
    });
  }

  void deleteSelectedNotes() {
    setState(() {
      notes =
          notes
              .asMap()
              .entries
              .where((entry) => !selectedNotes.contains(entry.key))
              .map((entry) => entry.value)
              .toList();
      selectedNotes.clear();
      isSelectionMode = false;
    });
  }

  void addNote() {
    setState(() {
      notes.add({'title': '', 'tasks': [], 'completed': []});
    });
  }

  void openNote(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return NoteDialog(
          note: notes[index],
          onTaskUpdated: () {
            setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: notes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            bool isSelected = selectedNotes.contains(index);
            return GestureDetector(
              onTap: () {
                if (isSelectionMode) {
                  toggleNoteSelection(index);
                } else {
                  openNote(index);
                }
              },
              onLongPress: () {
                if (!isSelectionMode) toggleSelectionMode();
                toggleNoteSelection(index);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[200] : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    notes[index]['title'],
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        overlayColor: Colors.black45,
        children: [
          if (isSelectionMode)
            SpeedDialChild(
              child: Icon(Icons.close, color: Colors.white),
              backgroundColor: Colors.red,
              label: 'Sair do modo seleção',
              onTap: toggleSelectionMode,
            ),
          if (isSelectionMode)
            SpeedDialChild(
              child: Icon(Icons.delete, color: Colors.white),
              backgroundColor: Colors.red,
              label: 'Excluir Selecionadas',
              onTap: deleteSelectedNotes,
            ),
          if (!isSelectionMode)
            SpeedDialChild(
              child: Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.green,
              label: 'Nova Nota',
              onTap: addNote,
            ),
          if (!isSelectionMode)
            SpeedDialChild(
              child: Icon(Icons.check_box, color: Colors.white),
              backgroundColor: Colors.orange,
              label: 'Selecionar Notas',
              onTap: toggleSelectionMode,
            ),
        ],
      ),
    );
  }
}

class NoteDialog extends StatefulWidget {
  final Map<String, dynamic> note;
  final VoidCallback onTaskUpdated;

  const NoteDialog({
    super.key,
    required this.note,
    required this.onTaskUpdated,
  });

  @override
  _NoteDialogState createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  TextEditingController taskController = TextEditingController();
  TextEditingController noteTitleController = TextEditingController();
  List<TextEditingController> taskTitleControllers = [];

  bool isEditingNoteTitle = false;
  Set<int> editingTaskIndices = {};

  @override
  void initState() {
    super.initState();
    noteTitleController.text = widget.note['title'];
    taskTitleControllers = List.generate(
      widget.note['tasks'].length,
      (index) => TextEditingController(text: widget.note['tasks'][index]),
    );
  }

  void addTask() {
    if (taskController.text.isNotEmpty) {
      setState(() {
        widget.note['tasks'].add(taskController.text);
        widget.note['completed'].add(false);
        taskTitleControllers.add(
          TextEditingController(text: taskController.text),
        );
        taskController.clear();
      });
      widget.onTaskUpdated();
    }
  }

  void toggleTask(int index) {
    setState(() {
      widget.note['completed'][index] = !widget.note['completed'][index];
    });
    widget.onTaskUpdated();
  }

  void deleteTask(int index) {
    setState(() {
      widget.note['tasks'].removeAt(index);
      widget.note['completed'].removeAt(index);
      taskTitleControllers.removeAt(index);
    });
    widget.onTaskUpdated();
  }

  void updateTaskTitle(int index, String newTitle) {
    setState(() {
      widget.note['tasks'][index] = newTitle;
    });
    widget.onTaskUpdated();
  }

  void toggleEditTask(int index) {
    setState(() {
      if (editingTaskIndices.contains(index)) {
        editingTaskIndices.remove(index);
      } else {
        editingTaskIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.only(left: 8, right: 8, top: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          isEditingNoteTitle
              ? Expanded(
                child: TextField(
                  controller: noteTitleController,
                  autofocus: true,
                  onSubmitted: (_) {
                    setState(() {
                      widget.note['title'] = noteTitleController.text;
                      isEditingNoteTitle = false;
                      widget.onTaskUpdated();
                    });
                  },
                ),
              )
              : Expanded(
                child: Text(
                  widget.note['title'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              setState(() {
                isEditingNoteTitle = true;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    decoration: InputDecoration(
                      hintText: 'Digite o título da nova tarefa',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.green),
                  onPressed: addTask,
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.note['tasks'].length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Checkbox(
                      value: widget.note['completed'][index],
                      onChanged: (_) => toggleTask(index),
                    ),
                    title:
                        editingTaskIndices.contains(index)
                            ? TextField(
                              controller: taskTitleControllers[index],
                              autofocus: true,
                              onSubmitted: (newText) {
                                updateTaskTitle(index, newText);
                                toggleEditTask(index);
                              },
                            )
                            : GestureDetector(
                              onTap: () => toggleEditTask(index),
                              child: Text(widget.note['tasks'][index]),
                            ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteTask(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
