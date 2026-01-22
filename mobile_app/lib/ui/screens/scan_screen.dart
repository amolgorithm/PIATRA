import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = false;
  String? _detectedItem;
  double? _confidence;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ingredients'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 100,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primaryGreen,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_detectedItem != null) ...[
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected: $_detectedItem',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${(_confidence! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_detectedItem == null) ...[
                  ElevatedButton.icon(
                    onPressed: _isScanning ? null : _simulateCapture,
                    icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.camera),
                    label: Text(_isScanning ? 'Processing...' : 'Capture'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.close),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addToPantry,
                          icon: const Icon(Icons.check),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Camera integration coming soon',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _simulateCapture() {
    setState(() {
      _isScanning = true;
    });

    // Simulate ML processing delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _detectedItem = 'Tomato';
          _confidence = 0.87;
        });
      }
    });
  }

  void _reset() {
    setState(() {
      _detectedItem = null;
      _confidence = null;
    });
  }

  void _addToPantry() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_detectedItem added to pantry'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }
}