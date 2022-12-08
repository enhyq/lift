import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lift/navigation_bar/bottom_navigation_bar.dart';
import 'package:lift/state_management/GalleryState.dart';
import 'package:lift/state_management/NavigationState.dart';
import 'package:lift/state_management/WorkoutState.dart';
import 'package:provider/provider.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';

class Profile extends StatelessWidget {
  late NavigationState _navigationState;

  @override
  Widget build(BuildContext context) {

    // Provider를 호출해 접근
    _navigationState = Provider.of<NavigationState>(context);
    GalleryState simpleGalleryState = Provider.of<GalleryState>(context, listen: false);
    WorkoutState simpleWorkoutState = Provider.of<WorkoutState>(context, listen: false);

    String uid = FirebaseAuth.instance.currentUser!.uid;
    var profileImage = null;
    try{
      profileImage = simpleWorkoutState.userData[uid]["profileImage"];
    }
    catch(e){}
    bool profileImageIsNull = (profileImage == null);

    TextEditingController controller = TextEditingController(
      text: "initial value"
    );
    TextFormField t = TextFormField(
      controller: controller,
    );
    controller.text = "new value";


    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
      ),
      body: ProfileScreen(
        auth: FirebaseAuth.instance,
        avatarSize: 200.0,
        // children: [
        //   Text("hi"),
        // ],
        actions: [
          /// When signing out, need to clear out all the user data
          /// Currently signing out doesn't do that
          /// Gallery data and DataPage data are kept which is not good
          SignedOutAction((context) {
            GoogleSignIn().signOut();
            FirebaseAuth.instance.signOut();

            simpleGalleryState.resetGallery();
            simpleWorkoutState.resetAll();

            Navigator.of(context).popAndPushNamed('/login');
          }),
        ],
        showMFATile: false,
      ),
    );
  }
}