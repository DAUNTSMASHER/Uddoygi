import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  try {
    print('Testing Firestore connection...');
    final snap = await FirebaseFirestore.instance.collection('companies').limit(1).get();
    print('Success! Found ${snap.docs.length} companies.');
    for (var doc in snap.docs) {
      print('Company ID: ${doc.id}, Data: ${doc.data()}');
    }
  } catch (e) {
    print('Firestore Error: $e');
  }
}
