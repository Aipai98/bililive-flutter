import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'pages/streamer_list_page.dart';
import 'pages/files_page.dart';
import 'pages/task_queue_page.dart';
import 'pages/settings_page.dart';

// 和 SettingsPage 保持一致的存储 key
const _kUrl = 'bili_server_url';
const _kPass = 'bili_server_pass';

Future<void> main() async {
  // 必须在读取 SharedPreferences 前初始化 binding
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService();
  try {
    final sp = await SharedPreferences.getInstance();
    final url = sp.getString(_kUrl) ?? '';
    if (url.isNotEmpty) {
      // 一打开 App 就恢复登录信息，各页直接可用，不必再进设置点保存
      api.setConfig(url, sp.getString(_kPass) ?? '');
    }
  } catch (_) {
    // 读不到配置也能正常启动，只是需要去设置页填一次
  }

  runApp(MyApp(api: api));
}

class MyApp extends StatelessWidget {
  final ApiService api;
  const MyApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
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
        indicatorColor: const Color(0x33FB7299),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.people_alt_rounded), label: '主播'),
          NavigationDestination(
              icon: Icon(Icons.folder_rounded), label: '文件'),
          NavigationDestination(
              icon: Icon(Icons.playlist_play_rounded), label: '任务队列'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded), label: '设置'),
        ],
      ),
    );
  }
}
