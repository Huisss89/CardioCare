import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// saveReadingToFirestore Helper
Future<void> saveReadingToFirestore({
  required String type,
  required Map<String, dynamic> data, // Accepts clean, non-Firestore data
}) async {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("Error: User not logged in. Cannot save to Firestore.");
    return;
  }

  // Create a COPY of the data and add Firestore-specific fields
  final Map<String, dynamic> firestoreData = Map.from(data);
  firestoreData['uid'] = user.uid;
  firestoreData['timestamp'] = FieldValue.serverTimestamp();

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readings')
        .add(firestoreData); // Use the firestoreData map

    print("Reading saved successfully to Firestore.");
  } catch (e) {
    print("Failed to save reading to Firestore: $e");
  }
}
