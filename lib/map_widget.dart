import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;

class MapWidget extends StatefulWidget {
  final List<Marker> markers;
  final VoidCallback? onLocationDisabled;

  const MapWidget({
    Key? key,
    required this.markers,
    this.onLocationDisabled,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final Completer<GoogleMapController> _controller = Completer();

  final CameraPosition kGooglePlex = const CameraPosition(
    target: LatLng(-15.971744, -47.789800),
    zoom: 13.800,
  );

  final Set<Polygon> polygons = HashSet<Polygon>();
  final Set<Polyline> polyLines = HashSet<Polyline>();

  bool drawPolygonEnabled = false;
  List<LatLng> userPolyLinesLatLngList = [];
  bool clearDrawing = false;
  int? lastXCoordinate;
  int? lastYCoordinate;

  List<Marker> markers = <Marker>[];

  List<Marker> filteredMarkers = <Marker>[];

  bool madePolygon = false;
  bool isFiltered = false;

  @override
  void initState() {
    super.initState();
    markers = widget.markers;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            GestureDetector(
              onPanUpdate: drawPolygonEnabled ? onPanUpdate : null,
              onPanEnd: drawPolygonEnabled ? onPanEnd : null,
              child: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: kGooglePlex,
                polygons: polygons,
                polylines: polyLines,
                markers: Set<Marker>.of(markers),
                onMapCreated: _controller.complete,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Visibility(
                      visible: drawPolygonEnabled,
                      child: FloatingActionButton.extended(
                        tooltip: 'Filtrar',
                        onPressed:
                            madePolygon && !isFiltered ? filterMarkers : null,
                        backgroundColor: madePolygon && !isFiltered
                            ? null
                            : Colors.blueGrey[300],
                        label: const Text(
                          'Filtrar',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      tooltip: 'Minha localização',
                      onPressed: () {
                        getCurrentPosition().then((value) {
                          setCurrentLocation(value.latitude, value.longitude);
                        });
                      },
                      child: const Icon(Icons.location_searching),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: toggleDrawing,
                      tooltip: 'Desenhar polígono',
                      child: Icon(
                        drawPolygonEnabled ? Icons.close : Icons.edit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  toggleDrawing() {
    clearPolygons();

    setState(() {
      drawPolygonEnabled = !drawPolygonEnabled;
      if (!drawPolygonEnabled) {
        madePolygon = false;
        isFiltered = false;
      }
    });
  }

  onPanUpdate(DragUpdateDetails details) async {
    // To start draw new polygon every time.
    if (clearDrawing) {
      clearDrawing = false;
      clearPolygons();
    }

    if (drawPolygonEnabled) {
      final pixRatio = MediaQuery.of(context).devicePixelRatio;

      late double x, y;
      x = details.globalPosition.dx * pixRatio;
      y = details.globalPosition.dy * pixRatio;

      int xCoor = x.round();
      int yCoor = y.round();

      if (lastXCoordinate != null && lastYCoordinate != null) {
        var distance = math.sqrt(math.pow(xCoor - lastXCoordinate!, 2) +
            math.pow(yCoor - lastYCoordinate!, 2));
        if (distance >= 80.0) return;
      }

      lastXCoordinate = xCoor;
      lastYCoordinate = yCoor;

      ScreenCoordinate scrCoor = ScreenCoordinate(x: xCoor, y: yCoor);
      final GoogleMapController controller = await _controller.future;
      LatLng latLng = await controller.getLatLng(scrCoor);

      try {
        userPolyLinesLatLngList.add(latLng);

        polyLines.removeWhere(
            (polyline) => polyline.polylineId.value == 'user_polyline');
        polyLines.add(
          Polyline(
            polylineId: const PolylineId('user_polyline'),
            points: userPolyLinesLatLngList,
            width: 2,
            color: Colors.blue,
          ),
        );
      } catch (e) {
        log("error painting $e");
      }
      setState(() {});
    }
  }

  onPanEnd(DragEndDetails details) async {
    // Reset last cached coordinate
    lastXCoordinate = null;
    lastYCoordinate = null;

    if (drawPolygonEnabled) {
      polygons
          .removeWhere((polygon) => polygon.polygonId.value == 'user_polygon');
      polygons.add(
        Polygon(
          polygonId: const PolygonId('user_polygon'),
          points: userPolyLinesLatLngList,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withOpacity(0.4),
        ),
      );
      setState(() {
        clearDrawing = true;
        madePolygon = true;
      });
    }
  }

  clearPolygons() {
    setState(() {
      polyLines.clear();
      polygons.clear();
      userPolyLinesLatLngList.clear();
      markers = widget.markers;
    });
  }

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      widget.onLocationDisabled?.call();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void setCurrentLocation(double lat, double long) async {
    final GoogleMapController controller = await _controller.future;

    final cameraPosition = CameraPosition(
      target: LatLng(lat, long),
      zoom: 13.4746,
    );

    controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  bool containsLocation(
    LatLng point,
    List<LatLng> polygon,
  ) {
    final pointConverted = maps_toolkit.LatLng(point.latitude, point.longitude);
    final polygonConverted = polygon.toList().map((latLang) {
      return maps_toolkit.LatLng(latLang.latitude, latLang.longitude);
    }).toList();
    return maps_toolkit.PolygonUtil.containsLocation(
      pointConverted,
      polygonConverted,
      true,
    );
  }

  void filterMarkers() {
    final List<Marker> markersCopy = List.from(markers);
    markersCopy.removeWhere(
      (element) => !containsLocation(element.position, polygons.first.points),
    );

    setState(() {
      markers = markersCopy;
      isFiltered = true;
    });
  }
}
