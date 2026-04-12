import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/sahaya_theme.dart';

class NgoHeatmapScreen extends StatefulWidget {
  final String ngoId;
  const NgoHeatmapScreen({super.key, required this.ngoId});

  @override
  State<NgoHeatmapScreen> createState() => _NgoHeatmapScreenState();
}

class _NgoHeatmapScreenState extends State<NgoHeatmapScreen> {
  final MapController _mapController = MapController();
  List<CircleMarker> _heatmapCircles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  Future<void> _loadHeatmapData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('problem_cards')
          .where('ngoId', isEqualTo: widget.ngoId)
          .where('status', isNotEqualTo: 'resolved')
          .get();

      List<CircleMarker> circles = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['locationGeoPoint'] != null) {
          GeoPoint gp = data['locationGeoPoint'];
          
          double radius = _getRadiusFromCount(data['affectedCount']);
          Color color = _getColorFromSeverity(data['severityLevel']);
          
          circles.add(
            CircleMarker(
              point: LatLng(gp.latitude, gp.longitude),
              color: color.withValues(alpha: 0.35),
              borderColor: color.withValues(alpha: 0.6),
              borderStrokeWidth: 2,
              useRadiusInMeter: true,
              radius: radius, 
            )
          );
        }
      }

      if (mounted) {
        setState(() {
          _heatmapCircles = circles;
          _isLoading = false;
        });
        
        if (circles.isNotEmpty) {
          final first = circles.first.point;
          _mapController.move(first, 12);
        }
      }
    } catch (e) {
      debugPrint('Error loading heatmap: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _getRadiusFromCount(dynamic count) {
    int c = 0;
    if (count is int) c = count;
    if (count is String) c = int.tryParse(count) ?? 0;
    if (c > 1000) return 5000.0;
    if (c > 500) return 3000.0;
    if (c > 100) return 1500.0;
    return 800.0;
  }

  Color _getColorFromSeverity(dynamic sev) {
    String s = (sev ?? 'low').toString().toLowerCase();
    switch (s) {
      case 'critical': return SahayaColors.coral;
      case 'high': return const Color(0xFFF97316); // orange
      case 'medium': return SahayaColors.amber;
      default: return SahayaColors.emerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Impact Heatmap', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHeatmapData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(13.0827, 80.2707), // Chennai Default 
              initialZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sahaya.sahaya',
              ),
              CircleLayer(
                circles: _heatmapCircles,
              ),
            ],
          ),
    );
  }
}
