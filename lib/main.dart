import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

//librairie module bluetooth BLE
import 'package:flutter_blue/flutter_blue.dart';
//librarie capteur
import 'package:sensors_plus/sensors_plus.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OSM Map Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _initDatabase();
    mapController.setZoom(zoomLevel: 18);
    _startAccelerometer();
  }

/*************ACCELEROMETRE**************/
  double _acceleration = 0.0;
  bool _isMoving = false;

  /* boolean pour savoir si l'accelerometre a deja depassé le seuil de mouvement
  * indique alors que le velo est en mouvement
  * utilisé car pour limiter l'envoie de data au module bluetooth, on envoie une seule
  * fois l'ordre d'allumer ou d'eteindre le frein
  *     false velo a l'arret
  *     true velo en mouvement
  */
  bool accelerationSupLimit = false;

  void _startAccelerometer() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      final double acceleration = event.x.abs() + event.y.abs() + event.z.abs();
      /*
      * POUR AFFICHER L'ACCELERATION D'UN TELEPHONE DANS LE TERMINAL
      * Si besoin pour tester la sensibilité du capteur
      *
      * print('$acceleration');
      */
      if (acceleration < 40.0) {
        if (accelerationSupLimit) {
          sendDataF();
          accelerationSupLimit = false;
        }
        setState(() {
          _isMoving = true;
        });
      } else {
        if (!accelerationSupLimit) {
          sendDataF();
          accelerationSupLimit = true;
        }
        setState(() {
          _isMoving = false;
        });
      }
      setState(() {
        _acceleration = acceleration;
      });
    });
  }

/*************ARDUINO************/
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;

  bool isScanning = false;
  List<BluetoothDevice> devices = [];

//etat du clignotant gauche
  bool indicatorOnG = false;

//etat du clignotant droit
  bool indicatorOnD = false;

//etat du frein
  bool indicatorOnF = false;

  /**
   * fonction pour rechercher les peripheriques bluetooth aux environ
   */
  void startScan() {
    setState(() {
      isScanning = true;
    });
    devices.clear();
    flutterBlue.scan(timeout: Duration(seconds: 5)).listen((scanResult) {
      if (scanResult.device.name.isNotEmpty) {
        setState(() {
          devices.add(scanResult.device);
        });
      }
      //Le module bluetooth arduino s'appelle 'HMSoft'
      //Si on le trouve, on se connecte automatiquement avec lui
      if (scanResult.device.name == 'HMSoft') {
        connect(scanResult.device);
      }
    }).onDone(() {
      setState(() {
        isScanning = false;
      });
    });
  }

/**
 * fonction pour etablir une connexion bluetooth avec un peripherique specifique
 */
  void connect(BluetoothDevice device) async {
    setState(() {
      targetDevice = device;
    });
    await targetDevice!.connect();
    List<BluetoothService> services = await targetDevice!.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString() == '0000ffe0-0000-1000-8000-00805f9b34fb') {
        targetCharacteristic = service.characteristics.firstWhere(
          (c) => c.uuid.toString() == '0000ffe1-0000-1000-8000-00805f9b34fb',
        );
      }
    });
  }

  /**
   * Meme si il est possible d'envoyer un String au moduble bluetooth arduino,
   * il la receptionne un caractère par un caractère
   * => on envoie donc uniquement un caractère pour lui donner un ordre
   * 
   * a allumer clignotant gauche
   * b eteindre clignotant gauche
   * c allumer clignotant droit
   * d eteindre clignotant droit
   * e allumer frein
   * f eteindre frein
   * 
   */

/**
 * gere l'envoi des ordres à l'arduino pour le clignotant gauche
 */
  void sendDataG() async {
    if (targetCharacteristic != null) {
      String message = "";
      if (!indicatorOnG) {
        message = "a";
        setState(() {
          indicatorOnG = true;
          indicatorOnD = false;
        });
      } else {
        message = "b";
        setState(() {
          indicatorOnG = false;
        });
      }

      List<int> bytes = utf8.encode(message);
      await targetCharacteristic!.write(bytes);
      print("Sent data: $message");
    } else {
      print("Error: targetCharacteristic is null");
    }
  }

/**
 * gere l'envoi des ordres à l'arduino pour le clignotant droit
 */
  void sendDataD() async {
    if (targetCharacteristic != null) {
      String message = "";
      if (!indicatorOnD) {
        message = "c";
        setState(() {
          indicatorOnD = true;
          indicatorOnG = false;
        });
      } else {
        message = "d";
        setState(() {
          indicatorOnD = false;
        });
      }

      List<int> bytes = utf8.encode(message);
      await targetCharacteristic!.write(bytes);
      print("Sent data: $message");
    } else {
      print("Error: targetCharacteristic is null");
    }
  }

/**
 * gere l'envoi des ordres à l'arduino pour le frein
 */
  void sendDataF() async {
    if (targetCharacteristic != null) {
      String message = "";
      if (!indicatorOnF) {
        message = "f";
        setState(() {
          indicatorOnF = true;
        });
      } else {
        message = "e";
        setState(() {
          indicatorOnF = false;
        });
      }

      List<int> bytes = utf8.encode(message);
      await targetCharacteristic!.write(bytes);
      print("Sent data: $message");
    } else {
      print("Error: targetCharacteristic is null");
    }
  }

  /************** FIN ARDUINO ******************/

  final MapController mapController = MapController.customLayer(
    initMapWithUserPosition: true,
    customTile: CustomTile(
      sourceName: "opentopomap",
      tileExtension: ".png",
      minZoomLevel: 10,
      maxZoomLevel: 19,
      urlsServers: [
        TileURLs(
          url: "https://tile.opentopomap.org/",
          subdomains: [],
        )
      ],
      tileSize: 256,
    ),
  );
  late Position _currentPosition;
  late Database _database;
  String? startAddress;
  double currentSpeed = 0.0;

  void _initDatabase() async {
    super.initState();
    _getCurrentLocation();
    _database = await openDatabase(
      'my_database.db',
      version: 1,
      onCreate: (db, version) {
        db.execute('CREATE TABLE IF NOT EXISTS trips ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'startAddress TEXT,'
            'endAddress TEXT,'
            'date TEXT)');
      },
    );
  }

  Future<void> _saveTrip(String? startAddress, String endAddress) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}:${now.second}';
    await _database.insert(
      'trips',
      {
        'startAddress': startAddress,
        'endAddress': endAddress,
        'date': date,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void _showTrips() async {
    final trips = await _database.query('trips');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Liste des trajets'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: trips.length,
              itemBuilder: (BuildContext context, int index) {
                final trip = trips[index];

                return ListTile(
                  title: Text('Départ : ${trip['startAddress']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arrivée : ${trip['endAddress']}'),
                      Text('Date : ${trip['date']}'),
                    ],
                  ),
                  onTap: () {
                    // Faire quelque chose lorsque l'utilisateur appuie sur un trajet
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _getCurrentLocation() async {
    while (true) {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _getCurrentLocation();
        _currentPosition = position;
        currentSpeed = position.speed ?? 0.0;

        startPoint = GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });

      List<Placemark> place =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      startAddress = place[0].street;

      await mapController.currentLocation();
    }
  }

  GeoPoint startPoint = GeoPoint(latitude: 0, longitude: 0);
  GeoPoint endPoint = GeoPoint(latitude: 0, longitude: 0);
  String address = '';
  late RoadInfo roadInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bike Tracking'),
        backgroundColor: Color.fromARGB(255, 9, 45, 83),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              child: Text('Menu'),
            ),
            ListTile(
              title: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.resolveWith<Color>((states) {
                    if (targetDevice == null) {
                      return Colors
                          .red; // Couleur rouge pour le bouton déconnecté
                    } else {
                      return Colors
                          .green; // Couleur verte pour le bouton connecté
                    }
                  }),
                  minimumSize: MaterialStateProperty.all<Size>(
                    const Size(60, 60), // taille personnalisée
                  ),
                ),
                onPressed: isScanning ? null : startScan,
                child: Text(
                  targetDevice == null
                      ? 'Vélo déconnecté !'
                      : 'Vélo connecté !',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ListTile(
              title: ElevatedButton(
                child: Text('Historique des trajets'),
                onPressed: () {
                  _showTrips();
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                      Color.fromARGB(255, 47, 55, 172)),
                  foregroundColor:
                      MaterialStateProperty.all<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                //BOUTON GAUCHE
                if (targetDevice != null)
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        indicatorOnG
                            ? Color.fromARGB(255, 255, 128, 0)
                            : Color.fromARGB(255, 255, 231, 183),
                      ),
                      shape: MaterialStateProperty.all<OutlinedBorder?>(
                        const CircleBorder(),
                      ),
                      minimumSize: MaterialStateProperty.all<Size>(
                        const Size(60, 60), // taille personnalisée
                      ), // taille personnalisée
                    ),
                    onPressed: sendDataG,
                    child: Icon(Icons.arrow_back_rounded,
                        color: Colors.black, size: 30),
                  ),

                //VITESSE
                if (targetDevice != null)
                  SizedBox(
                    height: 25,
                    child: Center(
                      child: Text(
                        " ${((currentSpeed * 3.6).toStringAsFixed(2))} km/h",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),

                //BOUTON DROIT
                if (targetDevice != null)
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        indicatorOnD
                            ? Color.fromARGB(255, 255, 128, 0)
                            : Color.fromARGB(255, 255, 231, 183),
                      ),
                      shape: MaterialStateProperty.all<OutlinedBorder?>(
                        const CircleBorder(),
                      ),
                      minimumSize: MaterialStateProperty.all<Size>(
                        const Size(60, 60), // taille personnalisée
                      ), // taille personnalisée
                    ),
                    onPressed: sendDataD,
                    child: Icon(Icons.arrow_forward_rounded,
                        color: Colors.black, size: 30),
                  ),

                if (targetDevice == null)
                  SizedBox(
                    height: 25,
                    child: Center(
                      child: Text(
                        "Veuillez connecter le vélo",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          //BOUTON FREIN
          if (targetDevice != null)
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.resolveWith<Color>((states) {
                  if (_isMoving) {
                    return Color.fromARGB(255, 255, 17, 0); // Couleur rouge vif
                  } else {
                    return const Color.fromARGB(
                        255, 245, 170, 165); // Couleur rouge claire
                  }
                }),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                minimumSize: MaterialStateProperty.all<Size>(
                  const Size(100, 35), // Dimensions personnalisées
                ),
              ),
              onPressed: () {
                sendDataF();
              },
              child: Container(), // Aucun contenu dans le bouton
            ),
          Expanded(
            child: OSMFlutter(
              controller: mapController,
              trackMyPosition: true,
              initZoom: 17.5,
              minZoomLevel: 8,
              maxZoomLevel: 19,
              stepZoom: 1.0,
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  icon: Icon(
                    Icons.pedal_bike,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
              roadConfiguration: RoadOption(
                roadColor: Colors.yellowAccent,
              ),
              markerOption: MarkerOption(
                defaultMarker: MarkerIcon(
                  icon: Icon(
                    Icons.person_pin_circle,
                    color: Colors.blue,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Adresse',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    address = value;
                  });
                },
              ),
            ),
          ),
          FloatingActionButton(
            child: Icon(Icons.directions),
            backgroundColor: Color.fromARGB(255, 9, 45, 83),
            onPressed: () async {
              // Transformer l'adresse en GeoPoint
              await mapController.removeLastRoad();
              List<Location> locations = await locationFromAddress(address);
              Location location = locations.first;
              setState(() {
                endPoint = GeoPoint(
                  latitude: location.latitude,
                  longitude: location.longitude,
                );
              });
              // Appel à la méthode drawRoad()
              roadInfo = await mapController.drawRoad(
                startPoint,
                endPoint,
                roadType: RoadType.bike,
                roadOption: RoadOption(
                  roadColor: Color.fromARGB(255, 255, 0, 0),
                  roadWidth: 6,
                ),
              );
              Timer(Duration(seconds: 5), () async {
                await mapController.currentLocation();
                await mapController.setZoom(zoomLevel: 18);

                _saveTrip(startAddress, address);
              });
            },
          ),
        ],
      ),
    );
  }
}
