

import 'package:firebase_auth/firebase_auth.dart';

import '../models/allUsers.dart';

final FirebaseAuth fAuth= FirebaseAuth.instance;
User? currentFirebaseUser;
String serverToken="key=AAAATwAuP8M:APA91bGWTboBi9V4QT4z9iDmpssWkY1_3tydRGD0kpJM3r1R_cj8JzOiz8eESEGA9oXleJ03jm62dfk9hOoefZKL28Zye7IVkcy9xXKzyZ-ZiWuFNJDpv5NE8ZDOv-NL6T5Dl31O4LIR";
int driverRequestTimeout=30;
String statusRide="";
String carDetailsDriver="";
String driverName="";
String driverPhone="";
String driveStatus="Driver is coming";
