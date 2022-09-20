import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:users_app/assistants/request_assistant.dart';
import 'package:users_app/dataHandler/app_data.dart';
import 'package:users_app/global/global.dart';
import 'package:users_app/global/map_key.dart';
import 'package:users_app/models/address.dart';
import 'package:users_app/models/allUsers.dart';
import 'package:users_app/models/direct_details.dart';
import 'package:http/http.dart' as http;

class AssistantMethods{
  static Future<String> searchCoordinateAddress(Position position,context)async{
    String placeAddress="";
    String st1,st2,st3,st4;
    String url="https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${mapKey}";
    var response = await RequestAssistant.getRequest(url);

    if(response!="failed"){
     // placeAddress=response["results"][0]["formatted_address"];
      st1=response["results"][0]["address_components"][1]["long_name"];
      st2=response["results"][0]["address_components"][2]["long_name"];
      st3=response["results"][0]["address_components"][3]["long_name"];
      st4=response["results"][0]["address_components"][4]["long_name"];
      placeAddress=st1 + ", " + st2 + ", " + st3 + ", " + st4;
      Address userPickupAddress=new Address();
      userPickupAddress.longitude=position.longitude;
      userPickupAddress.latitude=position.latitude;
      userPickupAddress.placeName=placeAddress;
      Provider.of<AppData>(context,listen: false).updatePickupLocationAddress(userPickupAddress);
    }
    return placeAddress;
  }
  static Future<DirectionDetails?> obtainPlaceDirectionsDetails(LatLng initialPosition,LatLng finalPosition)async{
    String directionUrl="https://maps.googleapis.com/maps/api/directions/json?origin=${initialPosition.latitude},${initialPosition.longitude}&destination=${finalPosition.latitude},${finalPosition.longitude}&key=${mapKey}";
    var res = await RequestAssistant.getRequest(directionUrl);
    if(res=="failed"){
      return null;
    }
    DirectionDetails directionDetails=DirectionDetails();

    directionDetails.encodedPoints=res["routes"][0]["overview_polyline"]["points"];
    directionDetails.distanceText=res["routes"][0]["legs"]["text"];
    directionDetails.distanceValue=res["routes"][0]["legs"]["value"];
    directionDetails.durationText=res["routes"][0]["duration"]["text"];
    directionDetails.durationValue=res["routes"][0]["duration"]["value"];

    return directionDetails;
  }
  static int calculateFares(DirectionDetails directionDetails){
    double timeTraveledFare=(directionDetails.durationValue!/60)*0.2;
    double distanceTraveledFare=(directionDetails.durationValue!/1000)*0.2;
    double totalFareAmount=timeTraveledFare+distanceTraveledFare;
    double totalLocalAmount=totalFareAmount*60;
    return totalLocalAmount.truncate();
  }
  static void getCurrentOnlineUserInfo()async{
    firebaseUser = await FirebaseAuth.instance.currentUser;
    String userId=firebaseUser!.uid;
    DatabaseReference reference=FirebaseDatabase.instance.ref().child("users").child(userId);

    reference.once().then((event){
      final dataSnapshot=event.snapshot;
      if(dataSnapshot.value!=null){
        userCurrentInfo=Users.fromSnapshot(dataSnapshot);
      }
    });
  }
  static double createRandomNumber(int num){
    var random=Random();
    int randNumber=random.nextInt(num);
    return randNumber.toDouble();
  }
  static sendNotificationToDriver(String token,context,String ride_request_id)async{
    var destination =Provider.of<AppData>(context,listen: false).dropOffLocation;
    Map<String,String> headerMap={
      "Content-type":"application/json",
      "Authorization":serverToken
    };
    Map notificationMap={
      "body":"DropOff Address,${destination!.placeName}",
      "title":"New Ride Request"
    };
    Map dataMap={
      "click_action":"FLUTTER_NOTIFICATION_CLICK",
      "id":"1",
      "status":"done",
      "ride_request_id":ride_request_id,
    };
    Map sendNotificationMap={
      "notification":notificationMap,
      "data":dataMap,
      "priority":"high",
      "to":token
    };
    // var res = await http.post(Uri.parse("https://fcm.google.com/fcm/send"),headers: headerMap,body: jsonEncode(sendNotificationMap));
  }
}