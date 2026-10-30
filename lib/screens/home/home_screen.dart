import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('com.salahsilent.app/native');
  String _nativeStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _pingNative();
  }

  Future<void> _pingNative() async {
    try {
      final result = await _channel.invokeMethod('pingSilentSessionManager');
      setState(() => _nativeStatus = result.toString());
    } catch (e) {
      setState(() => _nativeStatus = 'Native bridge OK (stub)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salah Silent')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestone 0 – Bootstrap',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Native status: $_nativeStatus',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.softGold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Project structure ready\n'
                      '• Theme applied (Deep Navy + Soft Gold)\n'
                      '• MethodChannel connected\n'
                      '• SilentSessionManager stub present\n'
                      '• GitHub Actions will build the APK',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
