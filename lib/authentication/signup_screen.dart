import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:users_app/splashScreen/splash_screen.dart';

import '../global/global.dart';
import '../widgets/progress_dialog.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _StateSignUpScreen createState() => _StateSignUpScreen();
}

class _StateSignUpScreen extends State<SignUpScreen> {
  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();

  validateForm(){
    if(nameTextEditingController.text.length<3){
      Fluttertoast.showToast(msg: "Name must be at least 3 characters");
    }
    else if(!emailTextEditingController.text.contains("@")){
      Fluttertoast.showToast(msg: "Email address is not valid");
    }
    else if(phoneTextEditingController.text.isEmpty){
      Fluttertoast.showToast(msg: "You must enter a phone number");
    }
    else if(passwordTextEditingController.text.length<6){
      Fluttertoast.showToast(msg: "Password must be at least 6 characters");
    }
    else{
      saveUserInfoNow();
    }
  }

  saveUserInfoNow()async{
    showDialog(context: context,
        barrierDismissible: false,
        builder: (BuildContext c){
          return ProgressDialog(message: "Processing...",);
        }
    );
    final User? firebaseUser=(
      await fAuth.createUserWithEmailAndPassword(
          email: emailTextEditingController.text.trim(),
          password: passwordTextEditingController.text.trim()
      ).catchError((msg){
          Navigator.pop(context);
          Fluttertoast.showToast(msg: "Error" + msg.toString());
      })
    ).user;

    if(firebaseUser!=null){
      Map usersMap = {
        "id": firebaseUser.uid,
        "name": nameTextEditingController.text.trim(),
        "email": emailTextEditingController.text.trim(),
        "phone": phoneTextEditingController.text.trim(),
      };

      DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("users");
      driversRef.child(firebaseUser.uid).set(usersMap);
      currentFirebaseUser=firebaseUser;
      Fluttertoast.showToast(msg: "Account has been created.");
      Navigator.push(context, MaterialPageRoute(builder: (c)=> MySplashScreen()));
    }
    else{
      Navigator.pop(context);
      Fluttertoast.showToast(msg: "Account has not been created.");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset("images/logo2.png"),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text("Register as a user.",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold)),
                TextField(
                  controller: nameTextEditingController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    color: Colors.blue,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Name",
                    hintText: "Enter Name",
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    hintStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextField(
                  controller: emailTextEditingController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    color: Colors.blue,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Email",
                    hintText: "Enter Email",
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    hintStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextField(
                  controller: phoneTextEditingController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.blue,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Phone",
                    hintText: "Enter Phone",
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    hintStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextField(
                  controller: passwordTextEditingController,
                  keyboardType: TextInputType.text,
                  obscureText: true,
                  style: const TextStyle(
                    color: Colors.blue,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Password",
                    hintText: "Enter Password",
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)),
                    hintStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    validateForm();
                  },
                  child: const Text(
                    "Create Account",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
              ],
            ),
          )),
    );
  }
}
