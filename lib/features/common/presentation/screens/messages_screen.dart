import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/inbox.dart';
import '../widgets/sent.dart';
import '../widgets/new.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userEmail = session != null && session['email'] != null ? session['email'] : '';
      _tabController = TabController(length: 3, vsync: this);
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (userEmail == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inbox), text: 'Inbox'),
            Tab(icon: Icon(Icons.send), text: 'Sent'),
            Tab(icon: Icon(Icons.create), text: 'New'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          InboxTab(userEmail: userEmail!),
          SentTab(userEmail: userEmail!),
          NewMessageTab(userEmail: userEmail!),
        ],
      ),
    );
  }
}
