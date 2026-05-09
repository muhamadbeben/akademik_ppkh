import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference collection(String path) => _db.collection(path);
  Future<DocumentSnapshot> getDocument(String col, String id) => _db.collection(col).doc(id).get();
  Future<void> setDocument(String col, String id, Map<String, dynamic> data) => _db.collection(col).doc(id).set(data);
  Future<void> updateDocument(String col, String id, Map<String, dynamic> data) => _db.collection(col).doc(id).update(data);
  Future<void> deleteDocument(String col, String id) => _db.collection(col).doc(id).delete();
  String generateId(String col) => _db.collection(col).doc().id;

  Future<QuerySnapshot> getCollection(String path, {String? orderBy, bool descending = false, Map<String, dynamic>? where}) {
    Query q = _db.collection(path);
    if (where != null) where.forEach((f, v) => q = q.where(f, isEqualTo: v));
    if (orderBy != null) q = q.orderBy(orderBy, descending: descending);
    return q.get();
  }

  Stream<QuerySnapshot> streamCollection(String path, {String? orderBy, bool descending = false}) {
    Query q = _db.collection(path);
    if (orderBy != null) q = q.orderBy(orderBy, descending: descending);
    return q.snapshots();
  }
}
