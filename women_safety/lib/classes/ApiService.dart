import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:women_safety/classes/CrimeData.dart';

class ApiService {
  final String baseUrl;

  // Constructor to accept the base URL
  ApiService(this.baseUrl);

  // Fetch crime data from the API
  Future<List<CrimeData>> fetchCrimeData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/crime_data'));

      if (response.statusCode == 200) {
        // Parse the response body into a list of CrimeData objects
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => CrimeData.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load crime data');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }
}
