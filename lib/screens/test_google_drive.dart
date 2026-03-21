import 'package:flutter/material.dart';
import 'package:hunting_signals/services/google_drive_service.dart';

/// Test screen for Google Drive integration
class TestGoogleDriveScreen extends StatefulWidget {
  const TestGoogleDriveScreen({super.key});

  @override
  State<TestGoogleDriveScreen> createState() => _TestGoogleDriveScreenState();
}

class _TestGoogleDriveScreenState extends State<TestGoogleDriveScreen> {
  bool _isLoading = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeGoogleDrive();
  }

  Future<void> _initializeGoogleDrive() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing...';
    });

    try {
      final success = await GoogleDriveService.initialize();
      setState(() {
        _status = success ? 'Google Drive initialized' : 'Failed to initialize';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSignIn() async {
    setState(() {
      _isLoading = true;
      _status = 'Signing in...';
    });

    try {
      final success = await GoogleDriveService.signIn();
      setState(() {
        _status = success ? 'Successfully signed in' : 'Sign in cancelled';
      });
    } catch (e) {
      setState(() {
        _status = 'Sign in error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSaveData() async {
    setState(() {
      _isLoading = true;
      _status = 'Saving data...';
    });

    try {
      // Create test data
      final testData = {
        'test_signal': {
          'id': 'test_001',
          'name': 'Test Signal',
          'description': 'This is a test signal for Google Drive integration',
          'category': 'Test',
          'timestamp': DateTime.now().toIso8601String(),
        }
      };

      final success = await GoogleDriveService.saveHuntingSignals(testData);
      setState(() {
        _status = success ? 'Data saved successfully' : 'Failed to save data';
      });
    } catch (e) {
      setState(() {
        _status = 'Save error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLoadData() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading data...';
    });

    try {
      final data = await GoogleDriveService.loadHuntingSignals();
      setState(() {
        _status = data != null ? 'Data loaded: ${data.keys.length} items' : 'No data found';
      });
    } catch (e) {
      setState(() {
        _status = 'Load error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSignOut() async {
    setState(() {
      _isLoading = true;
      _status = 'Signing out...';
    });

    try {
      await GoogleDriveService.signOut();
      setState(() {
        _status = 'Successfully signed out';
      });
    } catch (e) {
      setState(() {
        _status = 'Sign out error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Google Drive'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Drive Integration Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: $_status'),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Text(
                        'Ready for testing',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Test Sign In'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSaveData,
              icon: const Icon(Icons.save),
              label: const Text('Test Save Data'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testLoadData,
              icon: const Icon(Icons.download),
              label: const Text('Test Load Data'),
            ),
            
            const SizedBox(height: 8),
            
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Test Sign Out'),
            ),
            
            const SizedBox(height: 16),
            
            const Spacer(),
            
            Text(
              'Note: This is a test screen to verify Google Drive integration works correctly.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}