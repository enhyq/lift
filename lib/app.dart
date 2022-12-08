import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:lift/addImage.dart';
import 'package:lift/login.dart';
import 'package:lift/pose_detection.dart';
import 'package:lift/pose_detector_view.dart';
import 'package:lift/ranking.dart';
import 'package:lift/state_management/GalleryState.dart';
import 'package:lift/state_management/WorkoutState.dart';
import 'package:lift/profile.dart';
import 'package:lift/user_global_profile.dart';
import 'package:lift/workout.dart';
import 'package:lift/workouttest.dart';
import 'package:local_hero/local_hero.dart';
import 'package:provider/provider.dart';
import 'data.dart';
import 'home.dart';
import 'state_management/ApplicationState.dart';

class App extends StatelessWidget {
  const App({super.key, required this.loggedIn});

  final bool loggedIn;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final simpleAppState = Provider.of<ApplicationState>(
      context,
      listen: false,
    );

    final simpleWorkoutState = Provider.of<WorkoutState>(
      context,
      listen: false,
    );

    final simpleGalleryState = Provider.of<GalleryState>(
      context,
      listen: false,
    );

    /// if user is logged in, then Gallery data must be fetched
    /// before moving to the homePage
    if(loggedIn) {
      log("User is logged in and will download user data at initialization");
      simpleGalleryState.readGallery();
      simpleWorkoutState.getMyStreak();
      simpleWorkoutState.downloadWorkoutDates();
      simpleWorkoutState.downloadUserData();
    }

    // remove splash screen just before showing the initial screen
    FlutterNativeSplash.remove();

    log("------------ END OF INITIALIZATION ------------");

    return MaterialApp(
        debugShowCheckedModeBanner: false,
          title: 'Lift',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          // home: const HomePage(title: 'Lift'),

          // (FirebaseAuth.instance.currentUser == null)?'/login':'/'
          initialRoute: loggedIn?'/':'/login',
          routes: {
            '/': (context) => const HomePage(),
            '/addImagePage': (context) => const AddImagePage(),
            '/login': (context) => const LoginPage(),
            '/profile': (context) => Profile(),
            '/datapage': (context) => DataPage(),
            '/ranking': (context) => Ranking(),
            '/workout': (context) => WorkoutTest(),
            '/posepage': (context) => PoseDetectionPage(),
            '/posedemo': (context) => PoseDetectorView(),
            '/userGobalProfile': (context) => UserGlobalProfilePage(),
          },
    );
  }
}
