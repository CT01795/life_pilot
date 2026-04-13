import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/event_latln.dart';

class WidgetsEventMap extends StatefulWidget {
  final List<EventItem> events;
  final ControllerEvent controllerEvent;

  const WidgetsEventMap({
    super.key,
    required this.events,
    required this.controllerEvent,
  });

  @override
  State<WidgetsEventMap> createState() => _WidgetsEventMapState();
}

class _WidgetsEventMapState extends State<WidgetsEventMap> {
  GoogleMapController? _mapController;

  List<ClusterItem> _clusters = [];
  Set<Marker> _markers = {};

  final PageController _pageController =
      PageController(viewportFraction: 0.85);

  @override
  void initState() {
    super.initState();
  }

  void _rebuildClusters() async {
    final zoom = await _mapController?.getZoomLevel() ?? zoolLevel;

    _clusters = ClusterItem.buildClusters(widget.events, zoom);

    _buildMarkers();
  }

  void _buildMarkers() {
    final markers = _clusters.map((c) {
      if (c.isCluster) {
        return Marker(
          markerId: MarkerId('cluster_${c.id}'),
          position: c.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
          onTap: () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(c.position, 14),
            );
          },
        );
      }

      final e = c.single;

      return Marker(
        markerId: MarkerId(e.id),
        position: c.position,
        onTap: () {
          final index = widget.events.indexWhere((x) => x.id == e.id);

          if (index != -1) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
      );
    }).toSet();

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const Center(child: Text("No data"));
    }
    final first = widget.events.first;
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(first.lat ?? 23.6978, first.lng ?? 120.9605),
            zoom: zoolLevel,
          ),
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
            _rebuildClusters();
          },
          onCameraIdle: () {
            _rebuildClusters();
          },
        ),

        /// 📌 bottom card sync
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.events.length,
            onPageChanged: (index) {
              final e = widget.events[index];

              _mapController?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(e.lat!, e.lng!),
                ),
              );
            },
            itemBuilder: (_, i) {
              final e = widget.events[i];

              return Card(
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text(e.description),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}