import 'package:flutter/cupertino.dart';
import 'package:users_app/models/address.dart';

class AppData extends ChangeNotifier{
  Address? pickupLocation,dropOffLocation;
  void updatePickupLocationAddress(Address pickupAddress){
    pickupLocation=pickupLocation;
    notifyListeners();
  }
  void updateDropOffLocation(Address dropOffAddress){
    dropOffAddress=dropOffAddress;
    notifyListeners();
  }
}