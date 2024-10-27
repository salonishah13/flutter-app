import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'api_service.dart';
import 'package:women_safety/pages/map_page.dart'; // Import MapPage

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women Safety App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService apiService =
      ApiService('http://192.168.0.107:5000'); // Replace with your local IP

  List<CrimeData> crimeList = [];

  @override
  void initState() {
    super.initState();
    fetchCrimeData();
  }

  Future<void> fetchCrimeData() async {
    try {
      crimeList = await apiService.fetchCrimeData();
      print('Fetched ${crimeList.length} crime data entries.'); // Debugging line
      setState(() {}); // Refresh UI after fetching data
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Women Safety App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Women Safety App!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to the map page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapPage(crimeList: crimeList),
                  ),
                );
              },
              child: const Text('Go to Map'),
            ),
          ],
        ),
      ),
    );
  }
}
