import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'pages/streamer_list_page.dart';
import 'pages/files_page.dart';
import 'pages/task_queue_page.dart';
import 'pages/settings_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    return MaterialApp(
      title: 'biliLive',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        primaryColor: const Color(0xFFFB7299),
        useMaterial3: true,
      ),
      home: HomePage(api: api),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  final ApiService api;
  const HomePage({super.key, required this.api});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _idx = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      StreamerListPage(api: widget.api),
      FilesPage(api: widget.api),
      TaskQueuePage(api: widget.api),
      SettingsPage(api: widget.api),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv), label: '主播'),
          NavigationDestination(icon: Icon(Icons.folder), label: '文件'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: '任务队列'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
