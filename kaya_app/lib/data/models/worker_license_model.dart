class WorkerLicenseModel {
  final int? id;
  final int userId;
  final String licenseName;
  final String licenseNumber;
  final String issuingAuthority;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? documentPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerLicenseModel({
    this.id,
    required this.userId,
    required this.licenseName,
    required this.licenseNumber,
    required this.issuingAuthority,
    this.issueDate,
    this.expiryDate,
    this.documentPath,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerLicenseModel.fromJson(Map<String, dynamic> json) {
    return WorkerLicenseModel(
      id: json['id'],
      userId: json['user_id'],
      licenseName: json['license_name'],
      licenseNumber: json['license_number'],
      issuingAuthority: json['issuing_authority'],
      issueDate: json['issue_date'] != null ? DateTime.parse(json['issue_date']) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
      documentPath: json['document_path'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'license_name': licenseName,
      'license_number': licenseNumber,
      'issuing_authority': issuingAuthority,
      if (issueDate != null) 'issue_date': issueDate!.toIso8601String().split('T')[0],
      if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String().split('T')[0],
    };
  }
}
