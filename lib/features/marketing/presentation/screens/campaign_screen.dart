import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _proposalController = TextEditingController();

  User? user;
  bool isHead = false;
  bool isAdmin = false;
  String role = '';

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    checkUserRole();
  }

  @override
  void dispose() {
    _proposalController.dispose();
    super.dispose();
  }

  Future<void> checkUserRole() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      if (!mounted) return;
      if (doc.exists) {
        final r = (doc.data()?['role'] ?? '') as String;
        setState(() {
          role = r;
          isHead = r == 'marketing_head';
          isAdmin = r == 'admin' || r == 'ceo';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load role: $e')),
      );
    }
  }

  Future<void> submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('campaigns').add({
        'proposal': _proposalController.text.trim(),
        'status': 'pending',
        'submittedBy': u.uid,
        'timestamp': Timestamp.now(),
      });
      _proposalController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnack
