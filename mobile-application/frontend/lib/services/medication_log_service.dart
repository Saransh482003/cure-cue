import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MedicationLogService {
  static const String _logKey = 'medication_logs';

  static Future<void> logMedicationAction({
    required String action, // 'taken' or 'forgot'
    required String medicineName,
    required DateTime reminderTime,
    required DateTime actionTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existingLogs = await getMedicationLogs();
    
    final newLog = {
      'action': action,
      'medicineName': medicineName,
      'reminderTime': reminderTime.toIso8601String(),
      'actionTime': actionTime.toIso8601String(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    existingLogs.add(newLog);
    
    // Keep only the last 1000 logs to prevent excessive storage usage
    if (existingLogs.length > 1000) {
      existingLogs.removeRange(0, existingLogs.length - 1000);
    }
    
    await prefs.setString(_logKey, jsonEncode(existingLogs));
  }

  static Future<List<Map<String, dynamic>>> getMedicationLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString(_logKey);
    
    if (logsJson != null) {
      final List<dynamic> logsList = jsonDecode(logsJson);
      return logsList.cast<Map<String, dynamic>>();
    }
    
    return [];
  }

  static Future<List<Map<String, dynamic>>> getLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allLogs = await getMedicationLogs();
    
    return allLogs.where((log) {
      final actionTime = DateTime.parse(log['actionTime']);
      return actionTime.isAfter(startDate) && actionTime.isBefore(endDate);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getLogsByMedicine(String medicineName) async {
    final allLogs = await getMedicationLogs();
    
    return allLogs.where((log) => 
      log['medicineName'].toString().toLowerCase() == medicineName.toLowerCase()
    ).toList();
  }

  static Future<List<Map<String, dynamic>>> getLogsByAction(String action) async {
    final allLogs = await getMedicationLogs();
    
    return allLogs.where((log) => log['action'] == action).toList();
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }

  static Future<Map<String, int>> getActionStats() async {
    final allLogs = await getMedicationLogs();
    
    int takenCount = 0;
    int forgotCount = 0;
    
    for (var log in allLogs) {
      if (log['action'] == 'taken') {
        takenCount++;
      } else if (log['action'] == 'forgot') {
        forgotCount++;
      }
    }
    
    return {
      'taken': takenCount,
      'forgot': forgotCount,
      'total': allLogs.length,
    };
  }
}
