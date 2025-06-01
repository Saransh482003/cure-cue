import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/medication_log_service.dart';
import 'services/noti_serve.dart';
import 'theme_constants.dart';

class MedicationLogsScreen extends StatefulWidget {
  const MedicationLogsScreen({Key? key}) : super(key: key);

  @override
  State<MedicationLogsScreen> createState() => _MedicationLogsScreenState();
}

class _MedicationLogsScreenState extends State<MedicationLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'taken', 'forgot'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }    Future<void> _loadLogs() async {
    print('🔄 Loading medication logs...');
    setState(() => _isLoading = true);
    
    try {
      // DEBUG: Check what keys exist in storage
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      print('🔍 ALL STORAGE KEYS IN UI SCREEN: $allKeys');
      
      // Check if notification context marker exists
      final notifMarker = prefs.getString('notification_context_active');
      if (notifMarker != null) {
        print('✅ NOTIFICATION CONTEXT MARKER FOUND: $notifMarker');
        print('✅ UI and Notification contexts are SYNCHRONIZED');
      } else {
        print('❌ NO NOTIFICATION CONTEXT MARKER - contexts may be isolated');
      }
      
      // Check the exact key we're using
      final ourData = prefs.getString('medication_logs');
      print('🔍 MEDICATION_LOGS KEY DATA LENGTH: ${ourData?.length}');
      
      // Check if there are other medication-related keys
      for (String key in allKeys) {
        if (key.toLowerCase().contains('med') || key.toLowerCase().contains('log')) {
          final value = prefs.getString(key);
          print('🔍 RELATED KEY "$key": ${value?.length} chars');
        }
      }
      
      List<Map<String, dynamic>> logs = await MedicationLogService.getMedicationLogs();
      print('📦 LOGS FROM SERVICE: ${logs.length} total logs');
      if (logs.isNotEmpty) {
        print('📦 LATEST LOG: ${logs.first}');
      }
      print('📊 TOTAL LOGS COUNT: ${logs.length}');
      
      // Apply filter if needed
      if (_filter != 'all') {
        logs = logs.where((log) => log['action'] == _filter).toList();
        print('📊 FILTERED LOGS COUNT: ${logs.length}');
      }
      
      final stats = await MedicationLogService.getActionStats();
      
      // Debug prints to console
      print('📊 LOGS DEBUG: Total logs found: ${logs.length}');
      print('📊 FILTER: Current filter is: $_filter');
      print('📊 STATS DEBUG: $stats');
      
      if (logs.isNotEmpty) {
        // Print ALL logs for debugging
        print('📋 ALL LOGS:');
        for (int i = 0; i < logs.length; i++) {
          print('📊 LOG $i: ${logs[i]}');
        }
        
        // Sort logs by action time (most recent first)
        logs.sort((a, b) => 
          DateTime.parse(b['actionTime']).compareTo(DateTime.parse(a['actionTime']))
        );
      } else {
        print('❌ NO LOGS FOUND - checking storage directly...');
        // if (rawData != null && rawData.isNotEmpty) {
        //   print('⚠️ Storage has data but service returned empty - potential parsing issue');
        // }
      }
      
      if (mounted) {
        setState(() {
          _logs = logs;
          _stats = stats;
          _isLoading = false;
        });
        
        print('📊 UI UPDATE: Set ${_logs.length} logs in state');
        print('📊 UI STATE LOGS: $_logs');
      }
    } catch (e) {
      print('❌ ERROR loading logs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  // Add this method to _MedicationLogsScreenState
  Future<void> _testDirectStorage() async {
    print('🧪 Testing direct storage...');
    
    try {
      // Test the service directly
      await MedicationLogService.logMedicationAction(
        action: 'taken',
        medicineName: 'Direct Test Medicine',
        reminderTime: DateTime.now(),
        actionTime: DateTime.now(),
      );
      
      print('✅ Direct log added successfully');
      
      // Try to retrieve immediately
      List<Map<String, dynamic>> logs = await MedicationLogService.getMedicationLogs();
      print('📋 Retrieved logs: ${logs.length}');
      
      for (var log in logs) {
        print('📝 Log: $log');
      }
      
    } catch (e) {
      print('❌ Error in direct storage test: $e');
    }
  }
  String _formatDateTime(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Logs'),
        backgroundColor: ThemeConstants.primaryColor,
        foregroundColor: Colors.white,        
        actions: [
          // Test storage button
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Test Storage',
            onPressed: () async {
              await _testDirectStorage();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Storage test completed - check console')),
                );
              }
            },
          ),          // Test notification button
          IconButton(
            icon: const Icon(Icons.notification_add),
            tooltip: 'Test Notification Actions',
            onPressed: () async {
              try {
                await NotiService().testNotificationActions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification created - tap action buttons!')),
                  );
                }
              } catch (e) {
                print('❌ Error creating test notification: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          // Test context sync button
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Test Context Sync',
            onPressed: () async {
              try {
                print('🧪 Testing context synchronization...');
                await NotiService().testContextSynchronization();
                await _loadLogs(); // Refresh logs after test
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Context sync test completed - check console and logs!')),
                  );
                }
              } catch (e) {
                print('❌ Error in context sync test: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync test error: $e')),
                  );
                }
              }
            },
          ),
          // Debug button to fetch logs from storage
          IconButton(
            onPressed: () async {
              try {
                print('🔄 Fetching logs from device storage...');
                
                // Force refresh the logs display by fetching from storage
                await _loadLogs();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fetched ${_logs.length} logs from storage')),
                  );
                }
              } catch (e) {
                print('❌ Error fetching logs: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error fetching logs: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch logs from storage',
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Test Storage',
            onPressed: () async {
              await _testDirectStorage();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage test completed - check console')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
              _loadLogs();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Actions')),
              const PopupMenuItem(value: 'taken', child: Text('Taken Only')),
              const PopupMenuItem(value: 'forgot', child: Text('Forgot Only')),
            ],
            child: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Logs'),
                  content: const Text('Are you sure you want to clear all medication logs? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              
              if (result == true) {
                // await MedicationLogService.clearLogs();
                _loadLogs();
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Card
                if (_stats.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total', _stats['total'].toString(), Colors.blue),
                        _buildStatItem('Taken', _stats['taken'].toString(), Colors.green),
                        _buildStatItem('Forgot', _stats['forgot'].toString(), Colors.red),
                      ],
                    ),
                  ),
                
                // Logs List
                Expanded(
                  child: _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medication, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No medication logs found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Logs will appear here when you interact with medication reminders',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final isLastItem = index == _logs.length - 1;
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: isLastItem ? 16 : 8),
                              child: _buildLogItem(log),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log['action'];
    final medicineName = log['medicineName'];
    final reminderTime = _formatDateTime(log['reminderTime']);
    final actionTime = _formatDateTime(log['actionTime']);
    
    final isTaken = action == 'taken';
    final iconData = isTaken ? Icons.check_circle : Icons.cancel;
    final iconColor = isTaken ? Colors.green : Colors.red;
    final backgroundColor = isTaken ? Colors.green[50] : Colors.red[50];
    
    return Card(
      elevation: 2,
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(iconData, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Action: ${isTaken ? 'Taken' : 'Forgot'}',
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reminder: $reminderTime',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    'Logged: $actionTime',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
