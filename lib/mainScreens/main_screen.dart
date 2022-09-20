import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:users_app/assistants/assistant_methods.dart';
import 'package:users_app/assistants/geoFire_assistant.dart';
import 'package:users_app/authentication/login_screen.dart';
import 'package:users_app/dataHandler/app_data.dart';
import 'package:users_app/global/global.dart';
import 'package:users_app/global/map_key.dart';
import 'package:users_app/mainScreens/search_screen.dart';
import 'package:users_app/models/direct_details.dart';
import 'package:users_app/models/nearby_available_drivers.dart';
import 'package:users_app/widgets/divider.dart';
import 'package:users_app/widgets/no_driver_available_dialog.dart';
import 'package:users_app/widgets/progress_dialog.dart';

import '../models/allUsers.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin{

  Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;

  GlobalKey<ScaffoldState> scaffoldKey=new GlobalKey<ScaffoldState>();

  DirectionDetails? tripDirectionDetails;

  List<LatLng> pLineCoordinates=[];
  Set<Polyline> polylineSet = {};

  Position? currentPosition;
  var geoLocator=Geolocator();
  double bottomPaddingOfMap=0;

  Set<Marker> markers={};
  Set<Circle> circles={};

  double rideDetailsContainerHeight=0;
  double requestRideContainerHeight=0;
  double searchContainerHeight=300.0;
  double driverDetailsContainerHeight=0;

  bool drawerOpen=true;
  bool nearbyAvailableDriversKeyLoaded=false;

  DatabaseReference? rideRequestRef;
  BitmapDescriptor? nearbyIcon;
  List<NearbyAvailableDrivers> availableDrivers=[];
  String state="normal";
  StreamSubscription<DatabaseEvent>? rideStreamSubscription;
  bool isRequestingPositionDetails=false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    AssistantMethods.getCurrentOnlineUserInfo();
  }

  void saveRideRequest(){
    rideRequestRef=FirebaseDatabase.instance.ref().child("Ride Requests").push();
    var pickUp=Provider.of<AppData>(context,listen: false).pickupLocation;
    var dropOff=Provider.of<AppData>(context,listen: false).dropOffLocation;

    Map pickUpLocMap={
      "latitude": pickUp!.latitude.toString(),
      "longitude": pickUp!.longitude.toString(),
    };
    Map dropOffLocMap={
      "latitude": dropOff!.latitude.toString(),
      "longitude": dropOff!.longitude.toString(),
    };
    Map rideInfoMap={
      "driver_id": "waiting",
      "payment_method": "cash",
      "pickup":pickUpLocMap,
      "dropoff":dropOffLocMap,
      "created_at":DateTime.now().toString(),
      "rider_name":userCurrentInfo!.name,
      "rider_phone":userCurrentInfo!.phone,
      "pickup_address":pickUp.placeName,
      "dropoff_address":dropOff.placeName,
    };
    rideRequestRef!.set(rideInfoMap);
    rideStreamSubscription=rideRequestRef!.onValue.listen((event) {
      if(event.snapshot.value==null){
        return;
      }
      if((event.snapshot.value as Map)['car_details']!=null){
        setState(() {
          carDetailsDriver=(event.snapshot.value as Map)['car_details'].toString();
        });
      }
      if((event.snapshot.value as Map)['driver_name']!=null){
        setState(() {
          driverName=(event.snapshot.value as Map)['driver_name'].toString();
        });
      }
      if((event.snapshot.value as Map)['driver_phone']!=null){
        setState(() {
          driverPhone=(event.snapshot.value as Map)['driver_phone'].toString();
        });
      }
      if((event.snapshot.value as Map)['driver_phone']!=null){
        double driverLat=double.parse((event.snapshot.value as Map)['driver_location']['latitude'].toString());
        double driverLng=double.parse((event.snapshot.value as Map)['driver_location']['longitude'].toString());
        LatLng driverCurrentLocation=LatLng(driverLat, driverLng);
        if(statusRide=="accepted"){
          updateRideTimeToPickUpLocation(driverCurrentLocation);
        }
        else if(statusRide=="onride"){
          updateRideTimeToDropOffLocation(driverCurrentLocation);
        }
        else if(statusRide=="arrived"){
          setState(() {
            driveStatus="Driver has arrived.";
          });
        }
      }
       if((event.snapshot.value as Map)['status']!=null){
         statusRide=(event.snapshot.value as Map)['status'].toString();
       }
      if(statusRide=="accepted"){
        displayRiderDetailsContainer();
        Geofire.stopListener();
        deleteGeofireMarkers();
      }

    });
  }

  void deleteGeofireMarkers(){
    setState(() {
      markers.removeWhere((element) => element.markerId.value.contains("driver"));
    });
  }

  void updateRideTimeToPickUpLocation(LatLng driverCurrentLocation)async{
    if(isRequestingPositionDetails=false){
      isRequestingPositionDetails=true;
      var positionUserLatLng=LatLng(currentPosition!.latitude, currentPosition!.longitude);
      var details = await AssistantMethods.obtainPlaceDirectionsDetails(driverCurrentLocation, positionUserLatLng);
      if(details==null){
        return;
      }
      setState(() {
        driveStatus="Driver is coming - " + (details.durationText as String);
      });
      isRequestingPositionDetails=false;
    }
  }
  void updateRideTimeToDropOffLocation(LatLng driverCurrentLocation)async{
    if(isRequestingPositionDetails=false){
      isRequestingPositionDetails=true;
      var dropOff=Provider.of<AppData>(context,listen: false).dropOffLocation;
      var dropOffUserLatLng=LatLng(dropOff!.latitude as double, dropOff!.longitude as double);
      var details = await AssistantMethods.obtainPlaceDirectionsDetails(driverCurrentLocation, dropOffUserLatLng);
      if(details==null){
        return;
      }
      setState(() {
        driveStatus="Going to destination - " + (details.durationText as String);
      });
      isRequestingPositionDetails=false;
    }
  }


  void cancelRideRequest(){
    rideRequestRef!.remove();
    setState(() {
      state="normal";
    });
  }

  static const colorizeColors = [
    Colors.green,
    Colors.purple,
    Colors.pink,
    Colors.blue,
    Colors.yellow,
    Colors.red,
  ];

  static const colorizeTextStyle = TextStyle(
    fontSize: 55.0,
    fontFamily: 'Poppins',
  );

  void displayRequestRideContainer(){
    setState(() {
      requestRideContainerHeight=250.0;
      rideDetailsContainerHeight=0;
      bottomPaddingOfMap=230.0;
      drawerOpen=true;
    });
    saveRideRequest();
  }

  void displayDriverDetailsContainerHeight(){
    setState(() {
      requestRideContainerHeight=0.0;
      rideDetailsContainerHeight=0;
      bottomPaddingOfMap=280.0;
      driverDetailsContainerHeight=310.0;
    });
  }

  resetApp(){
    setState(() {
      drawerOpen=true;
      searchContainerHeight=300.0;
      rideDetailsContainerHeight=240.0;
      requestRideContainerHeight=0.0;
      bottomPaddingOfMap=230.0;
      polylineSet.clear();
      markers.clear();
      circles.clear();
      pLineCoordinates.clear();
    });
    locatePosition();
  }

  void displayRiderDetailsContainer()async{
    await getPlaceDirection();
    setState(() {
      searchContainerHeight=0;
      rideDetailsContainerHeight=0;
      bottomPaddingOfMap=230.0;
      drawerOpen=false;
    });
  }

  void locatePosition()async{
    LocationPermission permission;
    permission = await Geolocator.requestPermission();
    Position position=await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    currentPosition=position;

    LatLng latLngPosition=LatLng(position.latitude, position.longitude);
    CameraPosition cameraPosition = new CameraPosition(target: latLngPosition,zoom: 14);
    newGoogleMapController?.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    String address = await AssistantMethods.searchCoordinateAddress(position,context);
    print("This is your address: " + address);
    initGeoFireListener();
  }

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  @override
  Widget build(BuildContext context) {
    createIconMarker();
    return Scaffold(
      key: scaffoldKey,
      drawer: Container(
        color: Colors.white,
        width: 35.0,
        child: Drawer(
          child: ListView(
            children: [
              Container(
                height: 165.0,
                child: DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white),
                  child: Row(
                    children: [
                      Image.asset("images/logo.png",height: 65.0,width: 65.0,),
                      SizedBox(width: 16.0,),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Profile Name",style: TextStyle(fontSize: 16.0,color: Colors.black),),
                          SizedBox(height: 6.0,),
                          Text("Visit Profile")
                        ],
                      )
                    ],
                  ),
                ),
              ),
              DividerWidget(),
              SizedBox(height: 12.0,),
              Expanded(child: ListTile(
                leading: Icon(Icons.history),
                title: Text("History",style: TextStyle(fontSize: 16.0),),
              ),),
              Expanded(child: ListTile(
                leading: Icon(Icons.person),
                title: Text("Visit Profile",style: TextStyle(fontSize: 16.0),),
              ),),
              Expanded(child: ListTile(
                leading: Icon(Icons.info),
                title: Text("About",style: TextStyle(fontSize: 16.0),),
              ),),
              GestureDetector(
                onTap: (){
                  FirebaseAuth.instance.signOut();
                  Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
                },
                child: Expanded(child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text("Log out",style: TextStyle(fontSize: 16.0),),
                ),),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            padding: EdgeInsets.only(bottom: bottomPaddingOfMap),
            mapType: MapType.normal,
            myLocationButtonEnabled: true,
            initialCameraPosition: _kGooglePlex,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            polylines: polylineSet,
            markers: markers,
            circles: circles,
            onMapCreated: (GoogleMapController controller){
              _controllerGoogleMap.complete(controller);
              newGoogleMapController=controller;
              setState(() {
                bottomPaddingOfMap=300.0;
              });
              locatePosition();
            },
          ),
          Positioned(
            top: 38.0,
            left: 22.0,
            child: GestureDetector(
              onTap: (){
                if(drawerOpen){
                scaffoldKey.currentState?.openDrawer();
                }
                else{
                  resetApp();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 6.0,
                      spreadRadius: 0.5,
                      offset: Offset(0.7,0.7),

                    )
                  ]
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon((drawerOpen) ? Icons.menu : Icons.close,color: Colors.black,),
                  radius: 20.0,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: AnimatedSize(
              curve: Curves.bounceIn,
              duration: new Duration(milliseconds: 160),
              child: Container(
                height: searchContainerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(18.0),topRight: Radius.circular(18.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 16.0,
                      spreadRadius: 0.5,
                      offset: Offset(0.7,0.7),

                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0,vertical: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hey",style: TextStyle(fontSize: 12.0)),
                      Text("Where to",style: TextStyle(fontSize: 20.0)),
                    SizedBox(height: 20.0,),
                    GestureDetector(
                      onTap: ()async{
                        var res = await Navigator.push(context, MaterialPageRoute(builder: (c)=>SearchScreen()));
                        if(res=="obtainedDirections"){
                          displayRiderDetailsContainer();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 6.0,
                              spreadRadius: 0.5,
                              offset: Offset(0.7,0.7),

                            )
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(Icons.search,color: Colors.yellowAccent,),
                              SizedBox(width: 10.0),
                              Text("Search drop off"),
                            ],
                          ),
                        ),
                      ),
                    ),
                      SizedBox(height: 24.0),
                      Row(
                        children: [
                          Icon(Icons.home,color: Colors.grey,),
                          SizedBox(width: 12.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Provider.of<AppData>(context).pickupLocation!=null
                                  ? Provider.of<AppData>(context).pickupLocation?.placeName as String
                                  : "Add Home"
                              ),
                              SizedBox(height: 4.0,),
                              Text("Your current home address",style: TextStyle(color: Colors.black,fontSize: 12.0),)
                            ],
                          )
                        ],
                      ),
                      SizedBox(height: 10.0),
                      DividerWidget(),
                      SizedBox(height: 16.0),
                      Row(
                        children: [
                          Icon(Icons.work,color: Colors.grey,),
                          SizedBox(width: 12.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Add Work"),
                              SizedBox(height: 4.0,),
                              Text("Your current work address",style: TextStyle(color: Colors.black,fontSize: 12.0),)
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: AnimatedSize(
              curve: Curves.bounceIn,
              duration: new Duration(milliseconds: 160),
              child: Container(
                height: rideDetailsContainerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16.0),topRight: Radius.circular(16.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 16.0,
                      spreadRadius: 0.5,
                      offset: Offset(0.7,0.7),
                    ),
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 17.0),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: Colors.tealAccent[100],
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Image.asset("images/logo.png",height: 70.0,width: 80.0,),
                              SizedBox(width: 16.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Car",style: TextStyle(fontSize: 18.0,fontWeight: FontWeight.bold),),
                                  Text(((tripDirectionDetails!=null)? tripDirectionDetails!.distanceText as String : ''),style: TextStyle(fontSize: 16.0,fontWeight: FontWeight.bold,color: Colors.grey),),
                                ],
                              ),
                              Expanded(
                                child: Container(

                                ),

                              ),
                              Text(((tripDirectionDetails!=null)? '\$${AssistantMethods.calculateFares(tripDirectionDetails!)}':''),style: TextStyle(fontWeight: FontWeight.bold),),

                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20.0,),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children: [
                            Icon(FontAwesomeIcons.moneyCheck,size: 18.0,color: Colors.black54,),
                            SizedBox(width: 16.0,),
                            Text("Cash"),
                            SizedBox(width: 6.0,),
                            Icon(Icons.keyboard_arrow_down,size: 16.0,color: Colors.black54,),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.0,),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary
                      ),
                      onPressed: () {
                        setState(() {
                          state="requesting";
                        });
                        displayRequestRideContainer;
                        availableDrivers=GeoFireAssistant.nearbyAvailableDriversList;
                        searchNearestDriver();
                      },
                      child: Padding(
                        padding: EdgeInsets.all(17.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Request",style: TextStyle(fontSize: 20.0,fontWeight: FontWeight.bold,color: Colors.white),),
                            Icon(FontAwesomeIcons.taxi,color: Colors.white,size: 26.0,)
                          ],
                        ),
                      ),
                    ),
                  )
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0.0,
            right: 0.0,
            left: 0.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16.0),topRight: Radius.circular(16.0)),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    spreadRadius: 0.5,
                    blurRadius: 16.0,
                    color: Colors.black54,
                    offset: Offset(0.7,0.7)
                  )
                ]
              ),
              height: requestRideContainerHeight,
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    SizedBox(height: 12.0 ,),
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedTextKit(
                        animatedTexts: [
                          ColorizeAnimatedText(
                          'Requesting a ride...',
                            textStyle: colorizeTextStyle,
                            colors: colorizeColors,
                            textAlign: TextAlign.center,
                          ),
                          ColorizeAnimatedText(
                          'Please wait...',
                            textStyle: colorizeTextStyle,
                            colors: colorizeColors,
                            textAlign: TextAlign.center,
                          ),
                          ColorizeAnimatedText(
                          'Finding a driver',
                            textStyle: colorizeTextStyle,
                            colors: colorizeColors,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        isRepeatingAnimation: true,
                        onTap: () {
                        print("Tap Event");
                      },
                      ),
                    ),
                    SizedBox(height: 22.0 ,),
                    GestureDetector(
                      onTap: (){
                        cancelRideRequest();
                        resetApp();
                      },
                      child: Container(
                        height: 60.0,
                        width: 60.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26.0),
                          border: Border.all(width: 2.0,color: Colors.grey),
                        ),
                        child: Icon(Icons.close,size: 20.0,),
                      ),
                    ),
                    SizedBox(height: 10.0 ,),
                    Container(
                      width: double.infinity,
                      child: Text("Cancel ride",textAlign: TextAlign.center,style: TextStyle(fontSize: 12.0),),
                    )
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0.0,
            right: 0.0,
            left: 0.0,
            child: Container(
              decoration: BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16.0),topRight: Radius.circular(16.0)),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    spreadRadius: 0.5,
                    blurRadius: 16.0,
                    color: Colors.black54,
                    offset: Offset(0.7,0.7)
                  )
                ]
              ),
              height: driverDetailsContainerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0,vertical: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 6.0,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(driveStatus,textAlign: TextAlign.center,style: TextStyle(fontSize: 20.0,fontWeight: FontWeight.bold),),

                      ],
                    ),
                    SizedBox(height: 20.0,),
                    Divider(height: 2.0,thickness: 2.0,),
                    SizedBox(height: 20.0,),
                    Text(carDetailsDriver,style: TextStyle(color: Colors.grey),),
                    Text(driverName,style: TextStyle(fontSize: 20.0),),
                    SizedBox(height: 20.0,),
                    Divider(height: 2.0,thickness: 2.0,),
                    SizedBox(height: 20.0,),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: ElevatedButton(
                              onPressed: ()async{
                                // launch(('tel://${driverPhone}'));
                                print("telephone");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(17.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text("Call driver",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold,color: Colors.black),),
                                    Icon(Icons.call,color: Colors.white,size: 26.0,),
                                  ],
                                ),
                              ),
                            ),
                          )
                        ],
                    ),
                  ],
                ),
              ),
            ),

          ),
        ],
      ),
    );
  }
  Future<void> getPlaceDirection()async{
    var initialPos=Provider.of<AppData>(context,listen: false).pickupLocation;
    var finalPos=Provider.of<AppData>(context,listen: false).dropOffLocation;
    var pickUpLatLng = LatLng(initialPos?.latitude as double, initialPos?.longitude as double);
    var dropOffLatLng = LatLng(finalPos?.latitude as double, finalPos?.longitude as double);

    showDialog(context: context,
        builder: (BuildContext context)=>ProgressDialog(message: "Please wait..."),);
    var details = await AssistantMethods.obtainPlaceDirectionsDetails(pickUpLatLng, dropOffLatLng);
    setState(() {
      tripDirectionDetails=details;
    });
    Navigator.pop(context);

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPolyLinePointsResult = polylinePoints.decodePolyline(details?.encodedPoints as String);
    pLineCoordinates.clear();
    if(decodedPolyLinePointsResult.isNotEmpty){
      decodedPolyLinePointsResult.forEach((PointLatLng pointLatLng) {
        pLineCoordinates.add(LatLng(pointLatLng.latitude,pointLatLng.longitude));
      });
    }
    polylineSet.clear();
    setState(() {
      Polyline polyline = Polyline(
          color: Colors.pink,
          polylineId: PolylineId("PolylineId"),
          jointType: JointType.round,
          points: pLineCoordinates,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true
      );
      polylineSet.add(polyline);
    });

    LatLngBounds latLngBounds;
    if(pickUpLatLng.latitude>dropOffLatLng.latitude && pickUpLatLng.longitude>dropOffLatLng.longitude){
      latLngBounds=LatLngBounds(southwest: dropOffLatLng, northeast: pickUpLatLng);
    }
    else if(pickUpLatLng.longitude>dropOffLatLng.longitude){
      latLngBounds=LatLngBounds(southwest: LatLng(pickUpLatLng.latitude,dropOffLatLng.longitude), northeast: LatLng(dropOffLatLng.latitude,pickUpLatLng.longitude));
    }
    else if(pickUpLatLng.latitude>dropOffLatLng.latitude){
      latLngBounds=LatLngBounds(southwest: LatLng(dropOffLatLng.latitude,pickUpLatLng.longitude), northeast: LatLng(pickUpLatLng.latitude,dropOffLatLng.longitude));
    }else{
      latLngBounds=LatLngBounds(southwest: pickUpLatLng, northeast: dropOffLatLng);
    }
    newGoogleMapController?.animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 70));

    Marker pickUpLocationMarker = Marker(
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: initialPos?.placeName,snippet: "my Location"),
      position: pickUpLatLng,
      markerId: MarkerId("PickUpId ")
    );
    Marker dropOffLocationMarker = Marker(
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: finalPos?.placeName,snippet: "Drop Off Location"),
        position: dropOffLatLng,
        markerId: MarkerId("DropOffId ")
    );
    
    setState(() {
      markers.add(pickUpLocationMarker);
      markers.add(dropOffLocationMarker);
    });
    Circle pickUpLocationCircle = Circle(
        fillColor: Colors.green,
        center: pickUpLatLng,
        radius: 12,
        strokeWidth: 4,
        strokeColor: Colors.greenAccent,
        circleId: CircleId("PickUpId ")
    );
    Circle dropOffLocationCircle = Circle(
        fillColor: Colors.red,
        center: pickUpLatLng,
        radius: 12,
        strokeWidth: 4,
        strokeColor: Colors.red,
        circleId: CircleId("DropOffId ")
    );
    setState(() {
      circles.add(pickUpLocationCircle);
      circles.add(dropOffLocationCircle);
    });
  }

  void initGeoFireListener(){
    Geofire.initialize("availableDrivers");
    Geofire.queryAtLocation(currentPosition!.latitude, currentPosition!.longitude, 15)?.listen((map) {
      print(map);
      if (map != null) {
        var callBack = map['callBack'];
        switch (callBack) {
          case Geofire.onKeyEntered:
            NearbyAvailableDrivers nearbyAvailableDrivers = NearbyAvailableDrivers();
            nearbyAvailableDrivers.key=map['key'];
            nearbyAvailableDrivers.latitude=map['latitude'];
            nearbyAvailableDrivers.longitude=map['latitude'];
            GeoFireAssistant.nearbyAvailableDriversList.add(nearbyAvailableDrivers);
            if(nearbyAvailableDriversKeyLoaded==true){
              updateAvailableDriversOnMap();
            }
            break;

          case Geofire.onKeyExited:
            GeoFireAssistant.removeDriverFromList(map['key']);
            updateAvailableDriversOnMap();
            break;

          case Geofire.onKeyMoved:
            NearbyAvailableDrivers nearbyAvailableDrivers = NearbyAvailableDrivers();
            nearbyAvailableDrivers.key=map['key'];
            nearbyAvailableDrivers.latitude=map['latitude'];
            nearbyAvailableDrivers.longitude=map['latitude'];
            GeoFireAssistant.updateDriverNearbyLocation(nearbyAvailableDrivers);
            updateAvailableDriversOnMap();
            break;

          case Geofire.onGeoQueryReady:
            updateAvailableDriversOnMap();
            break;
        }
      }

      setState(() {});
    });
  }
  void updateAvailableDriversOnMap(){
    setState(() {
      markers.clear();
    });
    Set<Marker> tMarkers=Set<Marker>();
    for(NearbyAvailableDrivers driver in GeoFireAssistant.nearbyAvailableDriversList){
      LatLng driverAvailablePosition = LatLng(driver.latitude as double, driver.longitude as double);

      Marker marker=Marker(
        markerId: MarkerId('driver${driver.key}'),
        position: driverAvailablePosition,
        icon: nearbyIcon as BitmapDescriptor,
        rotation:AssistantMethods.createRandomNumber(360)
      );
      tMarkers.add(marker);
    }
    setState(() {
      markers=tMarkers;
    });
  }

  void createIconMarker(){
    if(nearbyIcon==null){
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context,size: Size(2, 2));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "images/logo.png").then((value)
      {
        nearbyIcon=value;
      }
      );
    }
  }
  void searchNearestDriver(){
    if(availableDrivers.length==0){
      cancelRideRequest();
      resetApp();
      noDriverFound();
      return;
    }
    var driver = availableDrivers[0];
    searchNearestDriver();
    availableDrivers.removeAt(0);
  }
  void noDriverFound(){
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context)=>NoAvailableDriverDialog(),
    );
  }
  void notifyDriver(NearbyAvailableDrivers driver){
    DatabaseReference driversRef=FirebaseDatabase.instance.ref().child("drivers");
    driversRef.child(driver.key as String).child("newRide").set(rideRequestRef!.key);
    driversRef.child(driver.key as String).child("token").once().then((event){
      final dataSnapshot=event.snapshot;
      if(dataSnapshot.value!=null){
        String token=dataSnapshot.value.toString();
        AssistantMethods.sendNotificationToDriver(token, context, rideRequestRef!.key as String);
      }
      else{
        return;
      }
      const oneSecondPassed=Duration(seconds: 1);
      var timer = Timer.periodic(oneSecondPassed, (timer) {
        if(state!="requesting"){
          driversRef.child(driver.key as String).child("newRide").set("cancelled");
          driversRef.child(driver.key as String).child("newRide").onDisconnect();
          driverRequestTimeout=30;
          timer.cancel();
        }
        driverRequestTimeout=driverRequestTimeout-1;
        driversRef.child(driver.key as String).child("newRide").onValue.listen((event) {
          if (event.snapshot.value.toString()=="accepted") {
            driversRef.child(driver.key as String).child("newRide").onDisconnect();
            driverRequestTimeout=30;
            timer.cancel();
          }
        });
        if(driverRequestTimeout==0){
          driversRef.child(driver.key as String).child("newRide").set("timeout");
          driversRef.child(driver.key as String).child("newRide").onDisconnect();
          driverRequestTimeout=30;
          timer.cancel();
          searchNearestDriver();
        }
      });
    });

  }
}
