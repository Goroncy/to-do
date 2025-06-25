import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('todo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        location TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER,
        title TEXT,
        completed INTEGER,
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> createNote(String title, {String? location}) async {
    final db = await instance.database;
    return await db.insert('notes', {
      'title': title,
      'location': location,
    });
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await instance.database;
    return await db.query('notes');
  }

  Future<int> updateNoteTitle(int id, String title) async {
    final db = await instance.database;
    return await db.update(
      'notes',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createTask(int noteId, String title, bool completed) async {
    final db = await instance.database;
    return await db.insert('tasks', {
      'note_id': noteId,
      'title': title,
      'completed': completed ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getTasksForNote(int noteId) async {
    final db = await instance.database;
    return await db.query('tasks', where: 'note_id = ?', whereArgs: [noteId]);
  }

  Future<int> updateTask(int id, String title, bool completed) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {'title': title, 'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

class LocationService {
  static Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Serviço de localização desabilitado');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permissão de localização negada');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização permanentemente negada');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<String?> getAddressFromCoordinates(Position position) async {
    try {
      final response = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
      return null;
    } catch (e) {
      print('Erro ao obter endereço: $e');
      return null;
    }
  }

  static Future<String?> getCurrentAddress() async {
    try {
      final position = await _getCurrentLocation();
      return await getAddressFromCoordinates(position);
    } catch (e) {
      print('Erro ao obter localização: $e');
      return null;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const NotesScreen(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
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
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notesList = await DatabaseHelper.instance.getNotes();

    List<Map<String, dynamic>> loadedNotes = [];

    for (var note in notesList) {
      final tasks = await DatabaseHelper.instance.getTasksForNote(note['id']);
      loadedNotes.add({
        'id': note['id'],
        'title': note['title'],
        'location': note['location'],
        'tasks': tasks.map((t) => t['title'] as String).toList(),
        'completed': tasks.map((t) => t['completed'] == 1).toList(),
        'task_ids': tasks.map((t) => t['id'] as int).toList(),
      });
    }

    setState(() {
      notes = loadedNotes;
    });
  }

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

  Future<void> deleteSelectedNotes() async {
    for (var index in selectedNotes.toList()) {
      await DatabaseHelper.instance.deleteNote(notes[index]['id']);
    }

    await _loadNotes();

    setState(() {
      selectedNotes.clear();
      isSelectionMode = false;
    });
  }

  Future<void> addNote() async {
    try {
      final address = await LocationService.getCurrentAddress();
      
      await DatabaseHelper.instance.createNote(
        'Nova Nota',
        location: address ?? 'Localização desconhecida',
      );
      
      await _loadNotes();
    } catch (e) {
      await DatabaseHelper.instance.createNote('Nova Nota');
      await _loadNotes();
      
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: ${e.toString()}')),
      );
    }
  }

  void openNote(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return NoteDialog(note: notes[index], onTaskUpdated: _loadNotes);
      },
    ).then((_) => _loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldMessengerKey,
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Notas com Localização'),
        centerTitle: true,
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteSelectedNotes,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: notes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  openNote(context, index);
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notes[index]['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (notes[index]['location'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              notes[index]['location'],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    if (notes[index]['tasks'].isNotEmpty)
                      Text(
                        '${notes[index]['tasks'].length} tarefa(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                  ],
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
              child: const Icon(Icons.close, color: Colors.white),
              backgroundColor: Colors.red,
              label: 'Sair do modo seleção',
              onTap: toggleSelectionMode,
            ),
          if (isSelectionMode)
            SpeedDialChild(
              child: const Icon(Icons.delete, color: Colors.white),
              backgroundColor: Colors.red,
              label: 'Excluir Selecionadas',
              onTap: deleteSelectedNotes,
            ),
          if (!isSelectionMode)
            SpeedDialChild(
              child: const Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.green,
              label: 'Nova Nota',
              onTap: addNote,
            ),
          if (!isSelectionMode)
            SpeedDialChild(
              child: const Icon(Icons.check_box, color: Colors.white),
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

  Future<void> addTask() async {
    if (taskController.text.isNotEmpty) {
      await DatabaseHelper.instance.createTask(
        widget.note['id'],
        taskController.text,
        false,
      );

      widget.onTaskUpdated();

      setState(() {
        widget.note['tasks'].add(taskController.text);
        widget.note['completed'].add(false);
        widget.note['task_ids'].add(widget.note['tasks'].length - 1);
        taskTitleControllers.add(
          TextEditingController(text: taskController.text),
        );
        taskController.clear();
      });
    }
  }

  Future<void> toggleTask(int index) async {
    final newCompleted = !widget.note['completed'][index];
    await DatabaseHelper.instance.updateTask(
      widget.note['task_ids'][index],
      widget.note['tasks'][index],
      newCompleted,
    );

    setState(() {
      widget.note['completed'][index] = newCompleted;
    });
    widget.onTaskUpdated();
  }

  Future<void> deleteTask(int index) async {
    await DatabaseHelper.instance.deleteTask(widget.note['task_ids'][index]);

    setState(() {
      widget.note['tasks'].removeAt(index);
      widget.note['completed'].removeAt(index);
      widget.note['task_ids'].removeAt(index);
      taskTitleControllers.removeAt(index);
    });
    widget.onTaskUpdated();
  }

  Future<void> updateTaskTitle(int index, String newTitle) async {
    await DatabaseHelper.instance.updateTask(
      widget.note['task_ids'][index],
      newTitle,
      widget.note['completed'][index],
    );

    setState(() {
      widget.note['tasks'][index] = newTitle;
    });
    widget.onTaskUpdated();
  }

  Future<void> updateNoteTitle() async {
    await DatabaseHelper.instance.updateNoteTitle(
      widget.note['id'],
      noteTitleController.text,
    );

    setState(() {
      widget.note['title'] = noteTitleController.text;
      isEditingNoteTitle = false;
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
      titlePadding: const EdgeInsets.only(left: 8, right: 8, top: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          isEditingNoteTitle
              ? Expanded(
                  child: TextField(
                    controller: noteTitleController,
                    autofocus: true,
                    onSubmitted: (_) => updateNoteTitle(),
                  ),
                )
              : Expanded(
                  child: Text(
                    widget.note['title'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              setState(() {
                isEditingNoteTitle = true;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.note['location'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.note['location'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      hintText: 'Digite o título da nova tarefa',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.green),
                  onPressed: addTask,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.note['tasks'].length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Checkbox(
                      value: widget.note['completed'][index],
                      onChanged: (_) => toggleTask(index),
                    ),
                    title: editingTaskIndices.contains(index)
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
                          icon: const Icon(Icons.delete, color: Colors.red),
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