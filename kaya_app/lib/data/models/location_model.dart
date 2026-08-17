/// A Philippine city or municipality from the PSGC dataset.
class LocationModel {
  const LocationModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.parentId,
    this.provinceName,
    this.regionName,
    this.latitude,
    this.longitude,
  });

  final int id;

  /// Enclosing place — a barangay's city, a city's province. Used to tell
  /// "inside the chosen city" apart from "somewhere else entirely".
  final int? parentId;

  /// Official PSGC name, e.g. "City of Urdaneta".
  final String name;

  /// Human-facing label, e.g. "Urdaneta City, Pangasinan".
  final String displayName;

  final String type;
  final String? provinceName;
  final String? regionName;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    return LocationModel(
      id: json['id'] as int,
      parentId: json['parent_id'] as int?,
      name: (json['name'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      provinceName: json['province_name'] as String?,
      regionName: json['region_name'] as String?,
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'type': type,
        'province_name': provinceName,
        'region_name': regionName,
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  bool operator ==(Object other) =>
      other is LocationModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
