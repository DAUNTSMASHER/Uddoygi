import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/common/complaints/new_complaint.dart';
import 'package:uddoygi/features/common/complaints/all_complaint.dart';
import 'package:uddoygi/features/common/complaints/punishment_reward.dart';
import 'package:uddoygi/features/common/complaints/pending_complaint.dart';
import 'package:uddoygi/features/common/complaints/complaint_actions.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _role = "user";
  String _userEmail = "";
  String _userName = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final session = await LocalStorageService.getSession();
    String role = (session?['role'] ?? "unknown").toLowerCase();
    final email = session?['email'] ?? "";
    final name = session?['name'] ?? email;

    if (role == "unknown" && email.isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        role = (userDoc.docs.first.data()['department'] ?? 'user').toLowerCase();
        await LocalStorageService.setSessionField('role', role);
      }
    }

    debugPrint("[DEBUG] Role: $role");
    debugPrint("[DEBUG] Email: $email");
    debugPrint("[DEBUG] Name: $name");

    final tabCount = (role == "admin" || role == "hr") ? 2 : 1;

    setState(() {
      _role = role;
      _userEmail = email;
      _userName = name;
      _tabController = TabController(length: tabCount, vsync: this);
      _loading = false;
    });
  }

  bool get isHrOrAdmin => _role == "admin" || _role == "hr";

  @override
  Widget build(BuildContext context) {
    debugPrint("[BUILD] isHrOrAdmin: $isHrOrAdmin");
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaints & Resolutions"),
        backgroundColor: Colors.indigo,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.indigo[200],
          indicatorColor: Colors.indigo,
          tabs: [
            const Tab(icon: Icon(Icons.report), text: "My Complaints"),
            if (isHrOrAdmin) const Tab(icon: Icon(Icons.assignment), text: "Complaint Resolution"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyComplaintsTab(
            userEmail: _userEmail,
            userName: _userName,
            role: _role,
          ),
          if (isHrOrAdmin)
            _ComplaintResolutionTab(
              userEmail: _userEmail,
              userName: _userName,
              role: _role,
            ),
        ],
      ),
    );
  }
}

class _MyComplaintsTab extends StatefulWidget {
  final String role;
  final String userEmail;
  final String userName;
  const _MyComplaintsTab({
    required this.role,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<_MyComplaintsTab> createState() => _MyComplaintsTabState();
}

class _MyComplaintsTabState extends State<_MyComplaintsTab> with TickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.grey[100],
          child: TabBar(
            controller: _subTabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.indigo[200],
            indicatorColor: Colors.indigo,
            tabs: const [
              Tab(icon: Icon(Icons.add), text: "New Complaint"),
              Tab(icon: Icon(Icons.history), text: "Previous Complaints"),
              Tab(icon: Icon(Icons.workspace_premium), text: "Punishment/Reward"),
              Tab(icon: Icon(Icons.warning_amber_rounded), text: "Against Me"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              NewComplaintScreen(userEmail: widget.userEmail),
              AllComplaintScreen(
                userEmail: widget.userEmail,
                userName: widget.userName,
              ),
              PunishmentRewardScreen(
                userEmail: widget.userEmail,

              ),
              _ComplaintsAgainstMeTab(
                userEmail: widget.userEmail,
                userName: widget.userName,
                role: widget.role,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComplaintsAgainstMeTab extends StatelessWidget {
  final String userEmail;
  final String userName;
  final String role;

  const _ComplaintsAgainstMeTab({
    required this.userEmail,
    required this.userName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('againstEmail', isEqualTo: userEmail)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No complaints filed against you."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final subject = data['subject'] ?? '(No Subject)';
            final message = data['message'] ?? '';
            final submittedBy = data['submittedByName'] ?? 'Someone';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(subject),
                subtitle: Text("Filed by: $submittedBy\n$message"),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _ComplaintResolutionTab extends StatefulWidget {
  final String role;
  final String userEmail;
  final String userName;

  const _ComplaintResolutionTab({
    required this.role,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<_ComplaintResolutionTab> createState() => _ComplaintResolutionTabState();
}

class _ComplaintResolutionTabState extends State<_ComplaintResolutionTab> with TickerProviderStateMixin {
  late TabController _resTabController;

  bool get isHrOrAdmin => widget.role == "admin" || widget.role == "hr";

  @override
  void initState() {
    super.initState();
    _resTabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[BUILD_RES_TAB] isHrOrAdmin: $isHrOrAdmin");
    if (!isHrOrAdmin) {
      return const Center(
        child: Text(
          "Unauthorized.\nOnly Admin and HR can access complaint resolution.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Column(
      children: [
        Material(
          color: Colors.grey[100],
          child: TabBar(
            controller: _resTabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.indigo[200],
            indicatorColor: Colors.indigo,
            tabs: const [
              Tab(icon: Icon(Icons.assignment_late), text: "Pending Complaints"),
              Tab(icon: Icon(Icons.build), text: "All Actions"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _resTabController,
            children: [
              PendingComplaintScreen(
                userEmail: widget.userEmail,
                isCEO: widget.role == "ceo",
              ),
              _AllComplaintActionsList(
                userName: widget.userName,
                userRole: widget.role,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllComplaintActionsList extends StatelessWidget {
  final String userName;
  final String userRole;
  const _AllComplaintActionsList({
    required this.userName,
    required this.userRole,
  });

  bool get isHrOrAdmin => userRole == "admin" || userRole == "hr";

  @override
  Widget build(BuildContext context) {
    debugPrint("[ACTIONS_LIST] role: $userRole");
    if (!isHrOrAdmin) {
      return const Center(
        child: Text(
          "Unauthorized.\nOnly Admin and HR can access complaint actions.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No complaints found."));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final subject = data['subject'] ?? '(No subject)';
            final id = docs[i].id;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: ListTile(
                title: Text(subject),
                subtitle: Text("Status: ${data['status'] ?? ''}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  if (isHrOrAdmin) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComplaintActionsScreen(
                          complaintId: id,
                          userName: userName,
                          userRole: userRole,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
