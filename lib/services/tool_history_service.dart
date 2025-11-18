import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/tool_history_item.dart';

/// 工具历史记录服务
class ToolHistoryService {
  static const String _historyFileName = 'tool_history.json';

  /// 获取历史记录文件路径
  Future<String> _getHistoryFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_historyFileName';
  }

  /// 加载所有历史记录
  Future<List<ToolHistoryItem>> loadHistory() async {
    try {
      final filePath = await _getHistoryFilePath();
      final file = File(filePath);

      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);

      return jsonList
          .map((json) => ToolHistoryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 加载历史记录失败: $e');
      return [];
    }
  }

  /// 保存历史记录
  Future<void> _saveHistory(List<ToolHistoryItem> items) async {
    try {
      final filePath = await _getHistoryFilePath();
      final file = File(filePath);

      final jsonList = items.map((item) => item.toJson()).toList();
      final jsonString = json.encode(jsonList);

      await file.writeAsString(jsonString);
    } catch (e) {
      print('❌ 保存历史记录失败: $e');
    }
  }

  /// 添加历史记录
  Future<void> addHistoryItem(ToolHistoryItem item) async {
    final history = await loadHistory();
    history.insert(0, item); // 最新的记录放在最前面

    // 限制历史记录数量（可选，例如最多保存1000条）
    if (history.length > 1000) {
      history.removeRange(1000, history.length);
    }

    await _saveHistory(history);
  }

  /// 删除历史记录
  Future<void> deleteHistoryItem(String id) async {
    final history = await loadHistory();
    history.removeWhere((item) => item.id == id);
    await _saveHistory(history);
  }

  /// 清空所有历史记录
  Future<void> clearHistory() async {
    await _saveHistory([]);
  }

  /// 按工具类型获取历史记录
  Future<List<ToolHistoryItem>> getHistoryByType(ToolType toolType) async {
    final history = await loadHistory();
    return history.where((item) => item.toolType == toolType).toList();
  }

  /// 获取按工具类型分组的历史记录
  Future<Map<ToolType, List<ToolHistoryItem>>> getHistoryGroupedByType() async {
    final history = await loadHistory();
    final Map<ToolType, List<ToolHistoryItem>> grouped = {};

    for (var type in ToolType.values) {
      grouped[type] = history.where((item) => item.toolType == type).toList();
    }

    return grouped;
  }
}

