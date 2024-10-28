class CrimeData {
  final String title;
  final String location;
  final double latitude;
  final double longitude;

  // Constructor
  CrimeData({
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  // Factory method to create a CrimeData object from JSON
  factory CrimeData.fromJson(Map<String, dynamic> json) {
    return CrimeData(
      title: json['title'],
      location: json['location'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}
