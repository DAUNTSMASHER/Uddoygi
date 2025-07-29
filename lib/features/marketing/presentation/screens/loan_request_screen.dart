import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> submitLoanRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to request a loan.')),
      );
      return;
    }

    final parsed = double.tryParse(_amountController.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('loan_requests').add({
        'userId': user!.uid,
        'amount': parsed,
        'status': 'pending', // other states: approved, completed, rejected
        'timestamp': Timestamp.now(),
      });
      _amountController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan request submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  Future<void> markReceived(String docId) async {
    try {
      await Fireba
