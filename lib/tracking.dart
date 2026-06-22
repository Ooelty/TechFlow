import 'dart:async';

import 'package:app_mobile/services/glpi_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MyTrackingPage extends StatefulWidget {
  final int ticketId;
  const MyTrackingPage({super.key, required this.ticketId});

  @override
  State<MyTrackingPage> createState() => _MyTrackingPageState();
}

class _MyTrackingPageState extends State<MyTrackingPage> {
  //les variables
  bool _isTracking = false; //pour verifier si le tracking est active
  bool _isLoading = false; //pour afficher un indicateur de chargement
  LatLng? _ticketLocation; // coordonnées du ticket
  String _ticketTitle = ''; // titre du ticket
  Position? _currentPosition; //position actuelle de technicien
  DateTime?
      _lastSentTime; //pour stocker la derniére fois qu'on a envoyé la position sur GLPI
  StreamSubscription<Position>?
      _positionStream; // pour gerer la mise a jour en temps réel de la position du technicien
  int _sendCount =
      0; //nombre de fois qu'on va envoiyer la mise a jour de position
  String _lastSent = '--:--'; //derniére heure d'envoi
  final MapController _mapController = MapController(); //contolleur de carte
  final List<LatLng> _markers =
      []; //liste de marker ou bien de ligne pour afficher la position du technicien ou la trajectoire du technicien sur la carte ou bien la position du ticket

  //gestion d'emplacement des tickets sur la carte
  @override
  void initState() {
    super.initState();
    _loadTicketAddress();
  }

  @override
  void dispose() {
    _positionStream
        ?.cancel(); //on annule le stream lorseque la page est détruite pour eviter les fuites de mémoire
    super.dispose();
  }

  //Gestion des permissions________
  //demande de permission pour acceder au gps
  Future<bool> _checkPermissions() async {
    //on verifie si les services de localisation sont activés sur le telephone
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Veuillez activer les services de localisation')),
      );
      return false;
    }

    //on verifie si l'app a la permission d'acceder au gps
    LocationPermission permission = await Geolocator.checkPermission();
    //Si la permission est refusé on va la demander a l'utilisateur pour laisser lapp accede au gps
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission de localisation refusée')),
        );
        return false;
      }
    }
    //si la permission est refusée l'utilisateur faut qu'il active manuellemennt
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Permission de localisation refusée définitivement. Veuillez l\'activer manuellement dans les paramètres.'),
        ),
      );
      return false;
    }

    return true; //tous les conditions sont remplies pour commencer le tracking
  }

  //_______________Recuperation de la position actuelle____________
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          // forceLocationManager: true, //  IMPORTANT pour Huawei
          distanceFilter: 5, //mise a jour tous les 5 metres
        ),
      );
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  //methode qui renvoir l'emplacement des tickets sur la carte
  Future<void> _loadTicketAddress() async {
    try {
      //  récupérer UN ticket avec son ID
      final ticket = await GLPIService.getTicketDetail(widget.ticketId);

      if (ticket == null) {
        return;
      }
      final locationId = ticket['locations_id'];

      if (locationId == null) {
        return;
      }
      //  récupérer la location
      final location = await GLPIService.getLocationById(locationId);

      if (location == null) {
        return;
      }
      //  récupérer coordonnées de location du ticket
      final lat = double.tryParse(location['latitude'].toString());
      final lng = double.tryParse(location['longitude'].toString());

      if (lat == null || lng == null) {
        return;
      }

      //  afficher sur la carte
      if (!mounted) return;
      setState(() {
        _ticketLocation = LatLng(lat, lng);
        _ticketTitle = ticket['title'] ?? 'Ticket #${widget.ticketId}';
      });
    } catch (e) {
      print("Erreur lors du chargement de l'emplacement du ticket: $e");
    }
  }

  //_________________Demarrage du Tracking____________________
  Future<void> _startTracking() async {
    if (!mounted) return;
    print("=== START TRACKING CLICK ===");
    setState(() {
      _isLoading = true; //au chargement on affiche l'indicateur de chargement
    });

    //Verification des Permissions
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      if (!mounted) return;
      print("PERMISSION REFUSED");
      setState(() => _isLoading = false);
      return; //si pas de permission on arrete le chargement
    }
    print("PERMISSION OK");

    //Recuperation de la position actuelle
    final position = await _getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    print("POSITION RECEIVED");

    //Convertir en LatLng pour afficher sur la carte
    final latLng = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _currentPosition = position; //on stock la position actuelle
      _markers.add(latLng);
      _isTracking = true; //le tracking est actif
      _isLoading = false; //on arrete l'indicateur de chargement
    });

    _mapController.move(latLng, 15);

    // ── STREAM GPS EN TEMPS RÉEL ──────────────────────────────
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // mise à jour tous les 5 mètres de déplacement
      ),
    ).listen((Position pos) async {
      final newLatLng = LatLng(pos.latitude, pos.longitude);

      // Mise à jour carte en temps réel à chaque mouvement
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _markers.add(newLatLng); // ajoute le point au trajet
        });
        _mapController.move(newLatLng, 15); // recentre la carte
      }

      // Envoie sur GLPI toutes les 20 secondes seulement
      final now = DateTime.now();
      final shouldSend = _lastSentTime == null ||
          now.difference(_lastSentTime!).inSeconds >= 20;

      if (shouldSend) {
        final success = await GLPIService.sendLocation(
          ticketId: widget.ticketId,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );

        if (success && mounted) {
          final time = TimeOfDay.now();
          setState(() {
            _sendCount++;
            _lastSentTime = now;
            _lastSent =
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          });
        }
      }
    });
  }

  //_________________Arret du Tracking____________________
  void _stopTracking() {
    _positionStream
        ?.cancel(); //on annule le stream de position pour arreter de recevoir les mises a jour de position
    if (!mounted) return;
    setState(() {
      _isTracking = false;
      _sendCount = 0;
      _lastSent = '--:--';
      _lastSentTime = null;
      _markers.clear(); // efface le trajet
    });
  }

  // ── WIDGET STAT ───────────────────────────────────────────
  Widget _buildStat(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Position par défaut → Casablanca si GPS pas encore actif
    final currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : LatLng(33.5731, -7.5898);

    return Scaffold(
      backgroundColor: Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(22, 82, 195, 1),
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Tracking — Ticket #${widget.ticketId}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── CARTE ─────────────────────────────────────────
          // Prend 60% de l'écran
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentLatLng,
                initialZoom: 15, // zoom niveau quartier
              ),
              children: [
                // Tuiles de la carte OpenStreetMap (gratuit, pas de clé API)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_mobile',
                  tileProvider:
                      CancellableNetworkTileProvider(), //pour tester le tracking sur le web sans faire trop de requetes au serveur de tuiles et eviter les blocages temporaires d'IP
                ),

                // Ligne du trajet (s'affiche seulement si 2+ points)
                if (_markers.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _markers,
                        strokeWidth: 4,
                        color: Color.fromRGBO(22, 82, 195, 1), // bleu
                      ),
                    ],
                  ),

                //marqueure de l'emplacement du ticket
                if (_ticketLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _ticketLocation!,
                        width: 60,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.red,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Marqueur position actuelle du technicien
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLatLng,
                        width: 60,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                // Vert si tracking actif, bleu sinon
                                color: _isTracking ? Colors.green : Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: _isTracking ? Colors.green : Colors.blue,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── PANNEAU BAS ───────────────────────────────────
          // Prend 40% de l'écran
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Info ticket
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.assignment,
                            color: Color.fromRGBO(22, 82, 195, 1), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Ticket ${widget.ticketId}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color.fromRGBO(22, 82, 195, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // Stats tracking
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(
                          '$_sendCount', 'Envois', Icons.send, Colors.blue),
                      _buildStat(_lastSent, 'Dernier envoi', Icons.access_time,
                          Colors.orange),
                      _buildStat(
                          '20s', 'Intervalle', Icons.timer, Colors.purple),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Coordonnées actuelles
                  if (_currentPosition != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.my_location, size: 14, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            // toStringAsFixed(5) = 5 décimales
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)} | Long: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 12),

                  // Bouton Start/Stop
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : _isTracking
                            ? _stopTracking
                            : _startTracking,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? Colors.grey
                            : _isTracking
                                ? Colors.red[400] // rouge = arrêter
                                : Colors.green[600], // vert = démarrer
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isTracking ? Icons.stop : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _isTracking
                                        ? 'Arrêter le tracking'
                                        : 'Démarrer le tracking',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
