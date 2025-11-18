import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/task_model.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  TaskProvider() {
    loadTasks();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final tasksDir = Directory(path.join(dir.path, 'tasks'));
      
      if (await tasksDir.exists()) {
        final files = tasksDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
        
        _tasks = [];
        for (var file in files) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content);
            _tasks.add(Task.fromJson(json));
          } catch (e) {
            debugPrint('加载任务失败: ${file.path}, 错误: $e');
          }
        }
        
        _tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('加载任务列表失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveTask(Task task) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tasksDir = Directory(path.join(dir.path, 'tasks'));
      
      if (!await tasksDir.exists()) {
        await tasksDir.create(recursive: true);
      }
      
      final file = File(path.join(tasksDir.path, '${task.taskId}.json'));
      await file.writeAsString(jsonEncode(task.toJson()));
      
      final index = _tasks.indexWhere((t) => t.taskId == task.taskId);
      if (index != -1) {
        _tasks[index] = task;
      } else {
        _tasks.insert(0, task);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('保存任务失败: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, 'tasks', '$taskId.json'));
      
      if (await file.exists()) {
        await file.delete();
      }
      
      _tasks.removeWhere((t) => t.taskId == taskId);
      notifyListeners();
    } catch (e) {
      debugPrint('删除任务失败: $e');
      rethrow;
    }
  }

  Task? getTask(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.taskId == taskId);
    } catch (e) {
      return null;
    }
  }
}

