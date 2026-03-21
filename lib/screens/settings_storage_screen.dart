import 'package:flutter/material.dart';
import 'package:hunting_signals/services/storage_manager.dart';

/// Settings screen with storage options
class SettingsStorageScreen extends StatefulWidget {
  const SettingsStorageScreen({super.key});

  @override
  State<SettingsStorageScreen> createState() => _SettingsStorageScreenState();
}

class _SettingsStorageScreenState extends State<SettingsStorageScreen> {
  StorageType _currentStorage = StorageManager.currentStorage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStorage();
  }

  Future<void> _loadCurrentStorage() async {
    setState(() {
      _currentStorage = StorageManager.currentStorage;
    });
  }

  Future<void> _changeStorageType(StorageType newType) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await StorageManager.setStorageType(newType);
      setState(() {
        _currentStorage = newType;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Тип зберігання змінено на: ${_getStorageTypeName(newType)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка зміни типу зберігання: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getStorageTypeName(StorageType type) {
    switch (type) {
      case StorageType.local:
        return 'Локальне сховище';
      case StorageType.googleDrive:
        return 'Google Drive';
      case StorageType.firebase:
        return 'Firebase';
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await StorageManager.createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Резервна копія створена' : 'Помилка створення резервної копії'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreFromBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await StorageManager.restoreFromBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Дані відновлено' : 'Не вдалося відновити дані'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showStorageInfo() async {
    try {
      final info = await StorageManager.getStorageInfo();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Інформація про сховище'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тип сховища: ${info['storageType'] ?? 'невідомий'}'),
                if (info['localStorage'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Локальні дані: ${info['localStorage']['itemCount'] ?? 0} елементів'),
                  Text('Розмір: ${info['localStorage']['totalSize'] ?? 0} байт'),
                ],
                if (info['googleDrive'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Google Drive: ${info['googleDrive']}'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка отримання інформації: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Налаштування'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Тип сховіщa даних',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Виберіть де зберігати дані програми:',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          // Radio selection with modern approach
                          RadioGroup<StorageType>(
                            groupValue: _currentStorage,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _currentStorage = value;
                                });
                                _changeStorageType(value);
                              }
                            },
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _currentStorage = StorageType.local;
                                    });
                                    _changeStorageType(StorageType.local);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Radio<StorageType>(
                                          value: StorageType.local,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Локальне сховище', style: Theme.of(context).textTheme.titleMedium),
                                              Text('Дані зберігаються на пристрої', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _currentStorage = StorageType.googleDrive;
                                    });
                                    _changeStorageType(StorageType.googleDrive);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Radio<StorageType>(
                                          value: StorageType.googleDrive,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Google Drive', style: Theme.of(context).textTheme.titleMedium),
                                              Text('Дані зберігаються в хмарі', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _currentStorage = StorageType.firebase;
                                    });
                                    _changeStorageType(StorageType.firebase);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Radio<StorageType>(
                                          value: StorageType.firebase,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Firebase (поточний)', style: Theme.of(context).textTheme.titleMedium),
                                              Text('Дані зберігаються в Firebase', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
          
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Резервні копії',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Керування резервними копіями:',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _createBackup,
                              icon: const Icon(Icons.backup),
                              label: const Text('Створити резервну копію'),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _restoreFromBackup,
                              icon: const Icon(Icons.restore),
                              label: const Text('Відновити з резервної копії'),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showStorageInfo,
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Інформація про сховище'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Поточне сховище: ${_getStorageTypeName(_currentStorage)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentStorage == StorageType.local
                              ? 'Дані зберігаються локально на пристрої'
                              : _currentStorage == StorageType.googleDrive
                                  ? 'Дані синхронізуються з Google Drive'
                                  : 'Дані зберігаються в Firebase',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
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