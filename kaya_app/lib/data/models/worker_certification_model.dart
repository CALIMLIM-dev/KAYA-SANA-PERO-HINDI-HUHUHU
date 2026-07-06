class WorkerCertificationModel {
  final int? id;
  final int userId;
  final String certificationName;
  final String issuingOrganization;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? credentialId;
  final String? documentPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerCertificationModel({
    this.id,
    required this.userId,
    required this.certificationName,
    required this.issuingOrganization,
    this.issueDate,
    this.expiryDate,
    this.credentialId,
    this.documentPath,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerCertificationModel.fromJson(Map<String, dynamic> json) {
    return WorkerCertificationModel(
      id: json['id'],
      userId: json['user_id'],
      certificationName: json['certification_name'],
      issuingOrganization: json['issuing_organization'],
      issueDate: json['issue_date'] != null ? DateTime.parse(json['issue_date']) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
      credentialId: json['credential_id'],
      documentPath: json['document_path'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'certification_name': certificationName,
      'issuing_organization': issuingOrganization,
      if (issueDate != null) 'issue_date': issueDate!.toIso8601String().split('T')[0],
      if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String().split('T')[0],
      if (credentialId != null) 'credential_id': credentialId,
    };
  }
}
