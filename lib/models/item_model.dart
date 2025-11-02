import 'package:cloud_firestore/cloud_firestore.dart';
class ItemModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime itemDateTime; // Date of loss/found
  final List<String>? imagePaths; // List of Firebase Storage URLs
  final String userId; // Reporter’s user ID
  final String officeId; // Office handling
  String status; // pending / verified / returned / rejected
  final String type; // lost / found
  final DateTime dateTime; // Reported date
  final DateTime createdAt; // Timestamp when added to Firestore
  String? verifiedBy; // Admin/staff who verified
  String? verifiedOfficeId; // Office that verified
  DateTime? verifiedAt; // Timestamp when verified
  // ✅ New fields for collection requests / ID verification
  String? collectionRequestId; // Latest collection request ID (optional)
  String? returnedRequestId; // ID of the request that completed/returned the item
  // String? idVerificationUrl; // REMOVED: Redundant field
  DateTime? returnedAt; // Timestamp when item is returned
  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.itemDateTime,
    this.imagePaths,
    required this.userId,
    required this.officeId,
    required this.status,
    required this.type,
    required this.dateTime,
    required this.createdAt,
    this.verifiedBy,
    this.verifiedOfficeId,
    this.verifiedAt,
    this.collectionRequestId,
    this.returnedRequestId,
    // this.idVerificationUrl, // REMOVED
    this.returnedAt,
  });
  /// Convert ItemModel → Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'itemDateTime': Timestamp.fromDate(itemDateTime),
      'imagePaths': imagePaths,
      'userId': userId,
      'officeId': officeId,
      'status': status,
      'type': type,
      'dateTime': Timestamp.fromDate(dateTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedBy': verifiedBy,
      'verifiedOfficeId': verifiedOfficeId,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'collectionRequestId': collectionRequestId,
      'returnedRequestId': returnedRequestId,
      // 'idVerificationUrl': idVerificationUrl, // REMOVED
      'returnedAt': returnedAt != null ? Timestamp.fromDate(returnedAt!) : null,
    };
  }
  /// Convert Firestore map → ItemModel
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      itemDateTime: map['itemDateTime'] is Timestamp
          ? (map['itemDateTime'] as Timestamp).toDate()
          : map['itemDateTime'] as DateTime,
      imagePaths: map['imagePaths'] != null
          ? List<String>.from(map['imagePaths'])
          : null,
      userId: map['userId'] ?? '',
      officeId: map['officeId'] ?? '',
      status: map['status'] ?? 'pending',
      type: map['type'] ?? '',
      dateTime: map['dateTime'] is Timestamp
          ? (map['dateTime'] as Timestamp).toDate()
          : map['dateTime'] as DateTime,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] as DateTime,
      verifiedBy: map['verifiedBy'],
      verifiedOfficeId: map['verifiedOfficeId'],
      verifiedAt: map['verifiedAt'] != null
          ? (map['verifiedAt'] is Timestamp
              ? (map['verifiedAt'] as Timestamp).toDate()
              : map['verifiedAt'] as DateTime)
          : null,
      collectionRequestId: map['collectionRequestId'],
      returnedRequestId: map['returnedRequestId'],
      // idVerificationUrl: map['idVerificationUrl'], // REMOVED
      returnedAt: map['returnedAt'] != null
          ? (map['returnedAt'] is Timestamp
              ? (map['returnedAt'] as Timestamp).toDate()
              : map['returnedAt'] as DateTime)
          : null,
    );
  }
  /// Copy with updated fields
  ItemModel copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? itemDateTime,
    List<String>? imagePaths,
    String? userId,
    String? officeId,
    String? status,
    String? type,
    DateTime? dateTime,
    DateTime? createdAt,
    String? verifiedBy,
    String? verifiedOfficeId,
    DateTime? verifiedAt,
    String? collectionRequestId,
    String? returnedRequestId,
    // String? idVerificationUrl, // REMOVED
    DateTime? returnedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      itemDateTime: itemDateTime ?? this.itemDateTime,
      imagePaths: imagePaths ?? this.imagePaths,
      userId: userId ?? this.userId,
      officeId: officeId ?? this.officeId,
      status: status ?? this.status,
      type: type ?? this.type,
      dateTime: dateTime ?? this.dateTime,
      createdAt: createdAt ?? this.createdAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedOfficeId: verifiedOfficeId ?? this.verifiedOfficeId,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      collectionRequestId: collectionRequestId ?? this.collectionRequestId,
      returnedRequestId: returnedRequestId ?? this.returnedRequestId,
      // idVerificationUrl: idVerificationUrl ?? this.idVerificationUrl, // REMOVED
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }
}