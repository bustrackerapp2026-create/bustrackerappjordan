import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';

class StatDetailsScreen extends StatefulWidget {
  final String title;
  final String queryType;

  const StatDetailsScreen({
    super.key,
    required this.title,
    required this.queryType,
  });

  @override
  State<StatDetailsScreen> createState() => _StatDetailsScreenState();
}

class _StatDetailsScreenState extends State<StatDetailsScreen> {
  List<QueryDocumentSnapshot> _latestDocs = const [];

  Query<Object?> _getFilteredQuery() {
    CollectionReference usersRef =
        FirebaseFirestore.instance.collection('users');

    switch (widget.queryType) {
      case 'passenger':
        return usersRef.where('userType', isEqualTo: 'passenger');
      case 'driver':
        return usersRef.where('userType', isEqualTo: 'driver');
      case 'service':
        return usersRef.where('userType', isEqualTo: 'service');
      case 'bus_company':
        return usersRef.where('userType', isEqualTo: 'bus_company');
      case 'pending':
        return usersRef
            .where('isVerified', isEqualTo: false)
            .where('isRejected', isEqualTo: false);
      case 'verified':
        return usersRef.where('isVerified', isEqualTo: true);
      case 'rejected':
        return usersRef.where('isRejected', isEqualTo: true);
      default:
        return usersRef;
    }
  }

  int? _indexOfDocKey(Key key) {
    if (key is! ValueKey<String>) return null;
    final id = key.value;
    for (var i = 0; i < _latestDocs.length; i++) {
      if (_latestDocs[i].id == id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('قائمة: ${widget.title}'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getFilteredQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('❌ حدث خطأ: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
            _latestDocs = docs;

            if (docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'لا توجد بيانات مطابقة حالياً',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              cacheExtent: 400,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              findChildIndexCallback: _indexOfDocKey,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final user = UserModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                );

                return Card(
                  key: ValueKey(user.uid),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.person, color: Colors.blue),
                    ),
                    title: Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(user.email),
                    trailing: Text(
                      user.userType,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
