import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';


class NgoHeatmapScreen extends StatefulWidget {
  final String ngoId;
  const NgoHeatmapScreen({super.key, required this.ngoId});

  @override
  State<NgoHeatmapScreen> createState() => _NgoHeatmapScreenState();
}

class _NgoHeatmapScreenState extends State<NgoHeatmapScreen> {
  final MapController _mapController = MapController();
  List<CircleMarker> _heatmapCircles = [];
  List<Marker> _interactiveMarkers = [];
  bool _isLoading = true;
  LatLng _initialCenter = const LatLng(13.0827, 80.2707);

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
      List<Marker> markers = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['locationGeoPoint'] != null) {
          GeoPoint gp = data['locationGeoPoint'];
          
          double radius = _getRadiusFromCount(data['affectedCount']);
          Color color = _getColorFromSeverity(data['severityLevel']);
          
          final point = LatLng(gp.latitude, gp.longitude);
          
          circles.add(
            CircleMarker(
              point: point,
              color: color.withValues(alpha: 0.35),
              borderColor: color.withValues(alpha: 0.6),
              borderStrokeWidth: 2,
              useRadiusInMeter: true,
              radius: radius, 
            )
          );
          
          markers.add(
            Marker(
              point: point,
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () => _showProblemDetails(context, data),
                child: Container(
                  color: Colors.transparent, // Invisible interactive zone
                  child: Center(
                    child: Icon(Icons.location_on_rounded, color: color, size: 24),
                  ),
                ),
              ),
            )
          );
        }
      }

      if (mounted) {
        setState(() {
          _heatmapCircles = circles;
          _interactiveMarkers = markers;
          if (circles.isNotEmpty) {
            _initialCenter = circles.first.point;
          }
          _isLoading = false;
        });
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

  void _showProblemDetails(BuildContext context, Map<String, dynamic> data) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final classification = (data['issueType']?.toString().toUpperCase() ?? 'OTHER');
    final customClass = data['customIssueType']?.toString();
    final displayName = classification == 'OTHER' && customClass != null 
        ? '$classification ($customClass)' 
        : classification;
        
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? SahayaColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  T(displayName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: cs.primary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _getColorFromSeverity(data['severityLevel']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: T(
                      (data['severityLevel']?.toString().toUpperCase() ?? 'MEDIUM'),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _getColorFromSeverity(data['severityLevel'])),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              T(
                data['description']?.toString() ?? 'No description provided.',
                style: GoogleFonts.inter(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  T('Est. Affected: ${data['affectedCount'] ?? 0}', style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  T('${data['locationWard'] ?? 'Unknown Ward'}, ${data['locationCity'] ?? 'Unknown City'}', 
                    style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: T('Impact Heatmap', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHeatmapData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter, // Chennai Default 
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
              MarkerLayer(
                markers: _interactiveMarkers,
              ),
            ],
          ),
    );
  }
}
