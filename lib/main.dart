import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';  // Importez le package intl pour utiliser NumberFormat
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Map App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  Position? currentPosition;
  Position? previousPosition;

  List<GeoPoint> selectedPoints = [];
  List<SearchInfo> currentSuggestions = [];


  String formattedDistance = "";
  String formattedDuration = "00" ;
  String formattedSpeed = "0.00" ;

  dynamic firstPlace;


  double speed = 0;

  final controller = MapController.withUserPosition(
    trackUserLocation: UserTrackingOption(
      enableTracking: true,
      unFollowUser: false,
    ),
  );

  MarkerIcon iconic = MarkerIcon(
    icon: Icon(
      Icons.location_pin,
      color: Colors.red,
      size: 60,
    ),
  );

  MarkerIcon iconicTrajetForSpeed = MarkerIcon(
    icon: Icon(
      Icons.location_pin,
      color: Colors.blue,
      size: 60,
    ),
  );


  double? distance = 0.0;
  double? duration = 0;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      initializeMap();
      setupMapListenerToDrawRoad();
      checkAndRequestLocationPermission();

      GeoPoint lomeGeoPoint = GeoPoint(latitude:  6.215011465501078, longitude: 1.2002710075464336);

      printLocationName(lomeGeoPoint, );


      Timer.periodic(Duration(seconds: 3), (timer) {
        calculateSpeed();
      });
    });

  }

  void getInitialLocation() async {
    currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    previousPosition = currentPosition;
    setState(() {});
  }

  void calculateSpeed() async {
    if (currentPosition != null && previousPosition != null) {
      double distance = Geolocator.distanceBetween(
        previousPosition!.latitude,
        previousPosition!.longitude,
        currentPosition!.latitude,
        currentPosition!.longitude,
      );

      // Introduire un seuil de distance minimum (par exemple, 0.1 mètre)
      double distanceThreshold = 3;

      if (currentPosition == previousPosition) {
        speed = 0.00 ;
      }

      if (distance >= distanceThreshold) {
        double time = (currentPosition!.timestamp.millisecondsSinceEpoch -
            previousPosition!.timestamp.millisecondsSinceEpoch) /
            1000;

        speed = distance / time;
        double speedInKmh = speed * 3.6;
        dynamic lat = currentPosition!.latitude;
        dynamic long = currentPosition!.longitude;

        formattedSpeed = NumberFormat("0.00").format(speedInKmh);
        speed = double.parse(formattedSpeed);

        setState(() {
          formattedSpeed = NumberFormat("0.00").format(speedInKmh);
          speed = double.parse(formattedSpeed);

          //GeoPoint geoPoint = GeoPoint(currentPosition.latitude, currentPosition.longitude);

          //controller.setMarkerIcon(currentPosition, iconicTrajetForSpeed);
          //controller.changeLocation(GeoPoint(latitude: lat, longitude: long));
          // initializeMap();setupMapListenerToDrawRoad



        });
      }
    }
    setMarkerOnMap();

    previousPosition = currentPosition;
    currentPosition =
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);



  }


  void setupMapListenerToDrawRoad() {
    controller.listenerMapSingleTapping.addListener(() {
      if (controller.listenerMapSingleTapping.value != null) {
        GeoPoint tappedPoint = controller.listenerMapSingleTapping.value!;

        controller.addMarker(
          tappedPoint,
          markerIcon: MarkerIcon(
            icon: Icon(
              Icons.location_pin,
              color: Colors.orange,
              size: 48,
            ),
          ),
        );

        selectedPoints.add(tappedPoint);

        print('Clic simple à la position : ${tappedPoint.latitude}, ${tappedPoint.longitude}');

        if (selectedPoints.length == 2) {
          drawRouteBetweenSelectedPoints();
        }
      }
    });
  }

  Future<void> _addMarkerToMap(GeoPoint point, MarkerIcon icon) async {
    await controller.addMarker(
      point,
      markerIcon: icon,
    );
  }

  Future<void> checkAndRequestLocationPermission() async {
    if (await Permission.location.isGranted) {
      print('Location permission granted');
      return;
    }

    var status = await Permission.location.request();
    if (status == PermissionStatus.granted) {
      print('Location permission granted');
      return;
    }
  }

  Future<void> GotoMyLocalisation() async{

    await controller.enableTracking(enableStopFollow: false);

    await Future.delayed(Duration(seconds: 3));

    GeoPoint userLocation = await controller.myLocation();
    double latitude = userLocation.latitude;
    double longitude = userLocation.longitude;
    print('User Location: Latitude $latitude, Longitude $longitude');

    if (mounted) {
      setState(() {
        controller.setZoom(zoomLevel: 18.5);
        controller.changeLocation(GeoPoint(latitude: userLocation.latitude, longitude: userLocation.longitude));
      });
    }

  }
  Future<String> getLocationName(GeoPoint location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
        localeIdentifier: 'fr',

      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;

        String name = placemark.name ?? '';

        String locality = placemark.locality ?? '';
        String sublocality = placemark.subLocality ?? '';
        String Subadministrative = placemark.subAdministrativeArea ?? '';
        String Country = placemark.country ?? '';

        // Concatène les informations pour former le nom de l'emplacement
        String completeLocationName = ' $name, $Subadministrative, $locality - $Country';

        return completeLocationName ?? '';
      } else {
        return 'Aucun emplacement trouvé.';
      }
    } catch (e) {
      return 'Erreur lors de la recherche de l\'emplacement : $e';
    }
  }

  Future<void> printLocationName(GeoPoint location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
        localeIdentifier: 'fr',
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;

        // Extrait les informations pertinentes
        String name = placemark.name ?? '';
        String locality = placemark.locality ?? '';
        String sublocality = placemark.subLocality ?? '';
        String Subadministrative = placemark.subAdministrativeArea ?? '';
        String Country = placemark.country ?? '';

        // Concatène les informations pour former le nom de l'emplacement
        String completeLocationName = ' $name, $Subadministrative, $locality, $Country';

        print('Geocoding Result: $placemark');
        print('Complete Location Name: $completeLocationName');
      } else {
        print('Aucun emplacement trouvé.');
      }
    } catch (e) {
      print('Erreur lors de la recherche de l\'emplacement : $e');
    }
  }

  void drawRouteBetweenSelectedPoints() async {
    GeoPoint startPoint = selectedPoints[0];
    GeoPoint endPoint = selectedPoints[1];

    // Ajoutez des marqueurs aux points de départ et d'arrivée
    await controller.addMarker(
      startPoint,
      markerIcon: MarkerIcon(
        icon: Icon(
          Icons.location_pin,
          color: Colors.orange,
          size: 48,
        ),
      ),
    );

    await controller.addMarker(
      endPoint,
      markerIcon: MarkerIcon(
        icon: Icon(
          Icons.location_pin,
          color: Colors.orange,
          size: 48,
        ),
      ),
    );

    try {
      RoadInfo roadInfo = await controller.drawRoad(
        startPoint,
        endPoint,
        roadType: RoadType.car,
        roadOption: RoadOption(
          roadWidth: 10.0,
          roadColor: Colors.blue,
          zoomInto: true,
        ),
      );

      // Formatez la distance avec deux chiffres après la virgule
      formattedDistance = NumberFormat("0.00").format(roadInfo.distance);

      // Formatez la durée en heures, minutes et secondes
      Duration duration = Duration(seconds: roadInfo.duration!.toInt());
      formattedDuration = "${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s";

      // Mettez à jour l'interface utilisateur
      setState(() {
        distance = double.parse(formattedDistance);  // Convertissez la distance en double
        this.duration = roadInfo.duration;
      });

      print("Distance: $formattedDistance km");
      print("Duration: $formattedDuration");
      print("Instructions: ${roadInfo.instructions}");
    } catch (e) {
      print("Erreur lors du tracé de la route : $e");
    }

    // Effacez la liste des points sélectionnés après avoir tracé la route
    // selectedPoints.clear();
  }


  /* Future<void> drawRoute() async {
    GeoPoint startPoint = GeoPoint(latitude: 6.128404793956687, longitude: 1.2147267366759973);
    GeoPoint endPoint = GeoPoint(latitude: 6.191565442513818, longitude: 1.1617370153777795);

    try {
      RoadInfo roadInfo = await controller.drawRoad(
        startPoint,
        endPoint,
        roadType: RoadType.car,
        roadOption: RoadOption(
          roadWidth: 10.0,
          roadColor: Colors.blue,
          zoomInto: true,
        ),
      );

      setState(() {
        distance = roadInfo.distance;
        duration = roadInfo.duration;
      });

      print("Distance: ${roadInfo.distance} km");
      print("Duration: ${roadInfo.duration} sec");
      print("Instructions: ${roadInfo.instructions}");
    } catch (e) {
      print("Error drawing route: $e");
    }
  } */

  void updateSuggestionsList(List<SearchInfo> newSuggestions) {
    setState(() {
      currentSuggestions = newSuggestions;
    });
  }

 /* void setMarkerOnMap() async {

    GeoPoint userdiaplacementLocation = await controller.myLocation();

    controller.addMarker(
      userdiaplacementLocation,
          markerIcon: MarkerIcon(
            icon: Icon(
              Icons.location_pin,
              color: Colors.blue,
              size: 48,
            ),
          ),
        );


    await Future.delayed(Duration(seconds: 2));
    await controller.removeMarker(userdiaplacementLocation);

  } */

  void setMarkerOnMap() async {
    // Obtenez la position actuelle de l'utilisateur
    GeoPoint userDiaplacementLocation = await controller.myLocation();

    // Créez un nouvel objet MarkerIcon avec la nouvelle icône si nécessaire
    MarkerIcon newMarkerIcon = MarkerIcon(
      icon: Icon(
        Icons.location_pin,
        color: Colors.blue,
        size: 48,
      ),
    );

    // Ajoutez le marqueur à la nouvelle position avec le nouvel icône
    controller.addMarker(
      userDiaplacementLocation,
      markerIcon: newMarkerIcon,
    );

    // Attendez quelques secondes (facultatif)
    await Future.delayed(Duration(seconds: 2));

    // Mettez à jour la propriété de l'icône du marqueur avec la nouvelle icône
    await controller.setMarkerIcon(userDiaplacementLocation, newMarkerIcon);
  }



  Future<void> initializeMap() async {

   // await controller.enableTracking(enableStopFollow: false);

    await Future.delayed(Duration(seconds: 4));

    await controller.enableTracking(enableStopFollow: false);

    await Future.delayed(Duration(seconds: 3));

    GeoPoint userLocation = await controller.myLocation();
    double latitude = userLocation.latitude;
    double longitude = userLocation.longitude;
    print('User Location: Latitude $latitude, Longitude $longitude');
    // controller.setZoom(zoomLevel: 17.5);

    if (mounted) {
      setState(() {
        controller.setZoom(zoomLevel: 17.5);
        controller.changeLocation(GeoPoint(latitude: userLocation.latitude, longitude: userLocation.longitude));
      });
    }



    //  await Future.delayed(Duration(seconds: 5));

  //  await drawRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
        style: TextStyle(
          color: Colors.white
        ),),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(

        child: Column(
          children: <Widget>[

            Container(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Recherchez un lieu...',
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
                onChanged: (query) async {
                  // Appel à la fonction addressSuggestion pour obtenir des suggestions
                  List<SearchInfo> suggestions = await addressSuggestion(query);


                  // Mettez à jour l'interface utilisateur avec les suggestions
                  // Cela pourrait inclure l'utilisation d'une liste déroulante ou d'une autre interface utilisateur pour afficher les suggestions.

                  // Exemple : Mise à jour d'une liste déroulante
                  updateSuggestionsList(suggestions);
                },
              ),
            ),

            // Liste déroulante des suggestions
            if (currentSuggestions.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(), // Permet le défilement
                  child: Container(
                    height: 200,
                    margin: EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: currentSuggestions.length,
                      itemBuilder: (context, index) {
                        SearchInfo suggestion = currentSuggestions[index];
                        return ListTile(
                          title: Text(
                            '${suggestion.address?.name ?? ''} , ${suggestion.address?.country ?? ''}',
                          ),
                          onTap: () {
                            controller.changeLocation(GeoPoint(
                              latitude: suggestion.point!.latitude,
                              longitude: suggestion.point!.longitude,
                            ));
                            controller.setZoom(zoomLevel: 18.5);
                            setState(() {
                              currentSuggestions.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Appel de la fonction GotoMyLocalisation pour aller à la position de l'utilisateur
                        GotoMyLocalisation();
                      },
                      child: Text('Aller à ma position'),
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(' ${distance} km'),
                        ],
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Icon(Icons.timer, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(' ${formattedDuration} sec'),
                        ],
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Icon(Icons.speed, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('${formattedSpeed} Km/H'),
                        ],
                      ),
                    ],
                  ),

                ],
              ),
            ),

            SizedBox(height: 10),

            Card(
              elevation: 4.0, // Contrôle l'ombre de la carte
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0), // Rayon des coins de la carte
                side: BorderSide(
                  color: Colors.black, // Couleur de la bordure
                  width: 2.0, // Largeur de la bordure
                ),
              ),
              child: Container(
                height: 350,
                child: controller != null
                    ? OSMFlutter(
                  controller: controller,
                  osmOption: OSMOption(
                    userLocationMarker: UserLocationMaker(
                      personMarker: MarkerIcon(
                        icon: Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 60,
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
                          color: Colors.red,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                )
                    : CircularProgressIndicator(),
              ),
            ),

            SizedBox(height: 18),


            Column(
              children: [
                // Votre code existant ici

                Container(
                  height: 160,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(height: 2,),
                      Text(
                        'Definissez vos adresses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                        ),
                      ),

                      Container(
                        height: 48,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(FontAwesomeIcons.mapMarker, color: Colors.blue), // Changement de l'icône pour l'adresse d'arrivée
                            Expanded(
                              child: FutureBuilder<String>(
                                future: selectedPoints.isNotEmpty ? getLocationName(selectedPoints[0]) : Future.value(''),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return CircularProgressIndicator(); // Ou un indicateur de chargement
                                  } else if (snapshot.hasError) {
                                    return Text('Erreur : ${snapshot.error}');
                                  } else {
                                    return snapshot.data != null && snapshot.data!.isNotEmpty
                                        ? Text(
                                      snapshot.data!,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                        : TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Adresse de départ...',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onTap: () {
                                        // Ajoutez ici le code pour gérer le clic sur le champ de texte
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(FontAwesomeIcons.pen, color: Colors.blue),
                              onPressed: () {
                                // Ajoutez ici le code pour modifier l'adresse d'arrivée
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 48,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(FontAwesomeIcons.locationArrow, color: Colors.blue), // Changement de l'icône pour l'adresse d'arrivée
                            Expanded(
                              child: FutureBuilder<String>(
                                future: selectedPoints.length > 1 ? getLocationName(selectedPoints[1]) : Future.value(''),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return CircularProgressIndicator(); // Ou un indicateur de chargement
                                  } else if (snapshot.hasError) {
                                    return Text('Erreur : ${snapshot.error}');
                                  } else {
                                    return snapshot.data != null && snapshot.data!.isNotEmpty
                                        ? Text(
                                      snapshot.data!,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                        : TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Adresse d\'arrivée...',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onTap: () {
                                        // Ajoutez ici le code pour gérer le clic sur le champ de texte
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(FontAwesomeIcons.pen, color: Colors.blue),
                              onPressed: () {
                                // Ajoutez ici le code pour modifier l'adresse d'arrivée
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2,),
                    ],
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

}

