import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:lift/model/Exercise.dart';
import 'package:lift/model/Workout.dart';

import '../firebase_options.dart';

class WorkoutState extends ChangeNotifier {
  List<Workout> _workouts = [];
  List<Workout> get workouts => _workouts;

  /// {"totalVolume", "streak", "BSD-Max"}
  Map<String, List<String>> volumeRanking = {};
  Map<String, List<String>> streakRanking = {};
  Map<String, List<String>> sbdSumRanking = {};
  int volumeRankingSize = 0;
  int streakRankingSize = 0;
  int sbdSumRankingSize = 0;

  void resetVolumeRanking() {
    volumeRanking.clear();
    volumeRanking.addAll({"user": [], "score": []});
    volumeRankingSize = 0;
  }
  void resetStreakRanking() {
    streakRanking.clear();
    streakRanking.addAll({"user": [], "score": []});
    streakRankingSize = 0;
  }
  void resetSBDSumRanking() {
    sbdSumRanking.clear();
    sbdSumRanking.addAll({"user": [], "score": []});
    sbdSumRankingSize = 0;
  }

  int myStreak = 0;

  /// for when logging out
  void resetAll() {
    workouts.clear();
    resetStreakRanking();
    resetSBDSumRanking();
    resetVolumeRanking();
    myStreak = 0; // reset myStreak
    currentYearWorkoutDates.clear();
    notifyListeners();
  }

  /// workoutDates
  /// for home page
  Map<DateTime, int> currentYearWorkoutDates = {};

  Future<Map<DateTime, int>> getWorkoutDates(String uid, {int? y}) async {
    Map<DateTime, int> wd = {};
    int year = 2022;
    year = DateTime.now().year;
    if(y != null){
      year = y;
    }
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection("User")
        .doc(uid)
        .collection("WorkoutDates")
        .doc("$year")
        .get();
    if(doc.exists) {
      for (final month in doc.data()!.keys) {
        List<dynamic> days = doc.get(month);
        for(int i=0; i<days.length; i++){
          if(days[i] == true){
            wd.addAll({DateTime(year, int.parse(month), i+1):13});
          }
        }
      }
    }
    return wd;
  }

  /// currently it only downloads current year's data
  void downloadWorkoutDates() async {
    currentYearWorkoutDates.clear();
    int year = 2022;
    year = DateTime.now().year;
    if(FirebaseAuth.instance.currentUser == null) return;
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection("User")
        .doc(uid)
        .collection("WorkoutDates")
        .doc("$year")
        .get();
    if(doc.exists) {
      for (final month in doc.data()!.keys) {
        List<dynamic> days = doc.get(month);
        for(int i=0; i<days.length; i++){
          if(days[i] == true){
            currentYearWorkoutDates.addAll({DateTime(year, int.parse(month), i+1):13});
          }
        }
      }
    }
    log("WS :: ${currentYearWorkoutDates.toString()}");
    notifyListeners();
  }

  /// uid used here must be continuously updated when user changes
  /// however, listening to FirebaseAuth user change is duplicated if it is also called here
  /// Therefore, when user uid is needed, let the function get it as parameter
  /// or get the current uesr's uid inside the function
  late CollectionReference<Map<String, dynamic>> userCollectionRef;
  late Query<Map<String, dynamic>> totalVolumeQuery;
  late Query<Map<String, dynamic>> streakQuery;
  late Query<Map<String, dynamic>> sbdSumQuery;

  /// user profile data
  late Map<String, dynamic> userData;

  /// initializer
  WorkoutState() {
    log("Creating WorkoutState");

    /// FirebaseFirestore instance can only be use after initialization
    init();
  }
  Future<void> init() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    userCollectionRef = FirebaseFirestore.instance.collection("User");
    totalVolumeQuery = userCollectionRef.orderBy('totalVolume', descending: true);
    streakQuery = userCollectionRef.orderBy('streak', descending: true);
    sbdSumQuery = userCollectionRef.orderBy('sbdSum', descending: true);
  }

  /// Demo of adding workout data to firebase
  void addSampleWorkout() {
    for (int i = 0; i < 1; i++) {
      Workout workout = Workout();
      workout.exercises
          .add(Exercise("Squat").addSet(100, 10).addSet(110, 8).addSet(120, 5));
      workout.exercises.add(
          Exercise("Bench").addSet(80, 10).addSet(70, 12).addSet(60, 16));
      workout.exercises.add(
          Exercise("Dead").addSet(80, 2).addSet(90, 3).addSet(120, 4));
      addWorkout(workout);
    }
    log("sample workout added");
  }

  /// This method searches for all workouts done at the given date
  /// and calculates the total volume done at that date
  /// if there is no workout at the provided date, it returns 0
  double getTotalVolumeAtDate(String date) {
    double totalVolume = 0.0;
    DateTime now = DateTime.parse(date);
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);

    for (final workout in workouts) {
      // createDate should not be null at this point
      DateTime workoutDay = workout.createDate!;
      if (workoutDay.isAfter(today) && workoutDay.isBefore(tomorrow)) {
        // log("${today}");
        for (final exercise in workout.exercises) {
          for (final set in exercise.Sets) {
            totalVolume += set['weight']! * set['reps']!;
            // log("${totalVolume} += ${set['weight']! * set['reps']!} (${set['weight']} * ${set['reps']})");
          }
        }
      }
    }
    return totalVolume;
  }

  Map<String, num> findMaxSBD(Workout workout) {
    Map<String, num> maxSBD = {"Squat":0, "Bench":0, "Dead":0};
    for(final exercise in workout.exercises) {
      if(exercise.Name == "Squat"){
        for(final set in exercise.Sets) {
          if(set["weight"]! > maxSBD["Squat"]!){
            maxSBD["Squat"] = set["weight"] as num;
          }
        }
      }
      if(exercise.Name == "Bench"){
        for(final set in exercise.Sets) {
          if(set["weight"]! > maxSBD["Bench"]!){
            maxSBD["Bench"] = set["weight"] as num;
          }
        }
      }
      if(exercise.Name == "Dead"){
        for(final set in exercise.Sets) {
          if(set["weight"]! > maxSBD["Dead"]!){
            maxSBD["Dead"] = set["weight"] as num;
          }
        }
      }
    }
    return maxSBD;
  }

  /// downloads current streak
  Future<void> getMyStreak() async {
    if(FirebaseAuth.instance.currentUser == null) return;
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance.collection("User").doc(uid).get();
    if (doc.data()!.containsKey("streak")) {
      myStreak = doc.get("streak");
    } else {
      myStreak = 0;
    }
    /// will nofity all at once when all required data are downloaded
    // notifyListeners();
  }

  Future<void> downloadStreakRanking() async {
    resetStreakRanking();
    await streakQuery.get().then((res) {
      if (res.size == 0) {
        log("no streak rankings");
        return;
      }
      for (DocumentSnapshot doc in res.docs) {
        // document id is user uid
        // each document contains "totalVolume" field
        /*
                currently the ranking system will display user uid instead of nickname
                however for security reasons this must be fixed if it is going to be released
                 */
        var data = doc.data() as Map<String, dynamic>;
        data.entries.where((element) => element.key == "streak");

        /// if nickName exsits, use nickName instead of uid
        streakRanking["user"]?.add(doc.id);
        log("STREAK :: ${data["streak"].toString()}");
        streakRanking["score"]?.add(data["streak"].toString());
        streakRankingSize++;
      }
      log("Ranks :: (Streak Ranking) :: ${streakRanking.toString()}");
      /// will nofity all at once when all required data are downloaded
      // notifyListeners(); // after successfully updating, need to notify listening widgets
    });
  }

  Future<void> downloadSBDSumRanking() async {
    resetSBDSumRanking();
    await sbdSumQuery.get().then((res) {
      if (res.size == 0) {
        log("no sbdSum rankings");
        return;
      }
      for (DocumentSnapshot doc in res.docs) {
        // document id is user uid
        // each document contains "totalVolume" field
        /*
                currently the ranking system will display user uid instead of nickname
                however for security reasons this must be fixed if it is going to be released
                 */
        var data = doc.data() as Map<String, dynamic>;
        data.entries.where((element) => element.key == "sbdSum");

        /// if nickName exsits, use nickName instead of uid
        sbdSumRanking["user"]?.add(doc.id);
        sbdSumRanking["score"]?.add(data["sbdSum"].toString());
        sbdSumRankingSize++;
      }
      log("Ranks :: (SBDsum Ranking) :: ${sbdSumRanking.toString()}");
      /// will nofity all at once when all required data are downloaded
      // notifyListeners(); // after successfully updating, need to notify listening widgets
    });
  }

  // void notifyListeners() {
  //   notifyListeners();
  // }

  Future<void> downloadUserData() async {
    userData = {}; // reset
    QuerySnapshot<Map<String, dynamic>> collection = await FirebaseFirestore.instance.collection("User").get();
    for(QueryDocumentSnapshot<Map<String, dynamic>>doc in collection.docs){
      Map<String, dynamic> data = doc.data();
      if(data == null || data.isEmpty) {
        userData["${doc.id}"] = {"nickname": "nickname", "profileImage":null};
      }
      userData["${doc.id}"] = {"nickname": data["nickname"], "profileImage":data["profileImage"]};
    }
  }

  void updatePageData(){
    notifyListeners();
  }


  /// change this to download all rankings ??
  Future<void> downloadVolumeRanking() async {
    // reset the outdated ranking
    resetVolumeRanking();
    await totalVolumeQuery.get().then((res) {
      if (res.size == 0) {
        log("no volume rankings");
        return;
      }
      for (DocumentSnapshot doc in res.docs) {
        // document id is user uid
        // each document contains "totalVolume" field
        /*
                currently the ranking system will display user uid instead of nickname
                however for security reasons this must be fixed if it is going to be released
                 */
        var data = doc.data() as Map<String, dynamic>;
        data.entries.where((element) => element.key == "totalVolume");

        /// if nickName exsits, use nickName instead of uid
        volumeRanking["user"]?.add(doc.id);
        log("Adding volumne: ${doc.id}");
        volumeRanking["score"]?.add(data["totalVolume"].toString());
        volumeRankingSize++;
      }
      log("Ranks :: (volumeRanking) :: ${volumeRanking.toString()}");
      /// will update once all data download completes
      // notifyListeners(); // after successfully updating, need to notify listening widgets
    });
    // since above operation is asynchronous, notifyListeners() must be called inside
  }

  /// aborted
  /// below function is not used and is not completed
  void downloadAllRanking() {
    // reset the outdated ranking
    resetVolumeRanking();
    resetSBDSumRanking();
    resetStreakRanking();

    totalVolumeQuery.get().then((res) {
      if (res.size == 0) {
        log("no volume rankings");
        return;
      }
      for (DocumentSnapshot doc in res.docs) {
        // document id is user uid
        // each document contains "totalVolume" field
        /*
                currently the ranking system will display user uid instead of nickname
                however for security reasons this must be fixed if it is going to be released
                 */
        var data = doc.data() as Map<String, dynamic>;
        data.entries.where((element) => element.key == "totalVolume");

        /// if nickName exsits, use nickName instead of uid
        volumeRanking["user"]?.add(doc.id);
        log("Adding volumne: ${doc.id}");
        volumeRanking["totalVolume"]?.add(data["totalVolume"].toString());
        volumeRankingSize++;
      }
      log("Ranks :: (all ranks download) :: ${volumeRanking.toString()}");
      notifyListeners(); // after successfully updating, need to notify listening widgets
    });
    // since above operation is asynchronous, notifyListeners() must be called inside
  }

  void editWorkout(Workout original, Workout workout) async{
    final data = workout.data();
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentReference<Map<String, dynamic>> userDocRef = userCollectionRef.doc(uid);
    /// calculate total volume of the workout
    num totalVolume = 0;
    for (final exercise in workout.exercises) {
      for (final set in exercise.Sets) {
        totalVolume += set['weight']! * set['reps']!;
      }
    }
    data["todayVolume"] = totalVolume;
    data["CreateDate"] = workout.createDate;

    int originalVolume = original.todayVolume!;

    DocumentSnapshot<Map<String, dynamic>> userDoc = await userDocRef.get();
    try {
      totalVolume += userDoc.get('totalVolume') as int;
      totalVolume -= originalVolume;
    } catch (e) {
      // log("there is no field");
    } finally {
      /// maybe doesn't really need to wait for finish uploading
      await userDocRef.set({"totalVolume": totalVolume}, SetOptions(merge: true));
    }

    await userDocRef.collection("Workout").doc(workout.docId).set(data, SetOptions(merge: true));
  }

  /// Upload a workout to Firestore
  /// It creates document of a workout with random id
  /// Checks ranking data and updates it too
  /// Adding workout could take quite a long time
  void addWorkout(Workout workout) async {
    final data = workout.data();
    String uid = FirebaseAuth.instance.currentUser!.uid;
    // <Map<String, dynamic>>
    DocumentReference<Map<String, dynamic>> userDocRef = userCollectionRef.doc(uid);

    /// calculate total volume of the workout
    num totalVolume = 0;
    for (final exercise in workout.exercises) {
      for (final set in exercise.Sets) {
        totalVolume += set['weight']! * set['reps']!;
      }
    }

    data["todayVolume"] = totalVolume;

    /// only for add workout
    /// upload workout data

    data["CreateDate"] = FieldValue.serverTimestamp();
    // data["CreateDate"] = Timestamp.fromDate(DateTime(2022, 11, 29));

    // set to server timestamp
    // <Map<String, dynamic>>
    DocumentReference addedDocRef =
    await userDocRef.collection("Workout").add(data);

    /// Get timestamp of the added workout
    // <Map<String, dynamic>>
    DocumentSnapshot addedDoc =
        await userDocRef.collection("Workout").doc(addedDocRef.id).get();
    Timestamp uploadTimeStamp = addedDoc.get(
        "CreateDate"); // this field must exist, since it is just added in the above code
    // DateTime uploadDateTime = DateTime.fromMicrosecondsSinceEpoch(uploadTimeStamp.microsecondsSinceEpoch);
    DateTime uploadDateTime = uploadTimeStamp.toDate();
    log("ADD :: ${uploadDateTime.toString()}");

    /// Update totalVolume
    DocumentSnapshot<Map<String, dynamic>> userDoc = await userDocRef.get();
    try {
      // log("******:${doc.get("totalVolume")}:******");
      totalVolume += userDoc.get('totalVolume') as int;
    } catch (e) {
      // log("there is no field");
    } finally {
      /// maybe doesn't really need to wait for finish uploading
      await userDocRef
          .set({"totalVolume": totalVolume}, SetOptions(merge: true));
    }

    /// Update Workout Dates List
    // manage documents yearly in a WorkoutDays collection
    // add uploadDateTime to the WorkoutDays collection
    final year = uploadDateTime.year;
    final month = uploadDateTime.month;
    final day = uploadDateTime.day;
    log("$year / $month / $day");
    // first get data in firestore
    DocumentSnapshot workoutYearDoc =
        await userDocRef.collection("WorkoutDates").doc("$year").get();
    List<dynamic> workoutMonth;

    if (workoutYearDoc.exists) {
      workoutMonth = workoutYearDoc.get("$month");
    } else {
      workoutMonth = [];
    }

    while (workoutMonth.length < day) {
      workoutMonth.add(false);
    }
    // set the last day (which is today) as true
    workoutMonth.last = true;
    // upload the new workoutDates data
    // merge allow other fields to remain as they are
    await userDocRef
        .collection("WorkoutDates")
        .doc("$year")
        .set({"$month": workoutMonth}, SetOptions(merge: true));

    /// just search for user workout? (SKIP THIS - this is just an idea)
    // userDocRef.collection("Workout")
    //     .where('CreatedDate', isLessThanOrEqualTo: now)
    //     .where('endDate', isGreaterThanOrEqualTo: now)
    // userDocRef.set({"workoutDates":});

    /// Update Streak
    /// Streak is not updated by adding workouts for the previous dates
    // create "streak" field under user doc
    // streak is added one if last workout date is only one day before today's date
    // else it is reset to zero
    // need to check if last workout date field exists
    Timestamp lastWorkoutTimeStamp;
    // check if streak is zero

    Map<String, dynamic>? docData = userDoc.data();
    if(docData != null && docData.keys.contains("lastWorkout")){
      lastWorkoutTimeStamp = userDoc.get("lastWorkout");
      int streak = userDoc.get("streak") as int;
      if(streak == 0){
        userDocRef.set(
          {"streak": 1, "streakStartDate":uploadTimeStamp},
          SetOptions(merge: true),
        );
      }
      else{
        DateTime lastWorkoutDateTime = lastWorkoutTimeStamp.toDate();
        DateTime u = DateTime(
            uploadDateTime.year, uploadDateTime.month, uploadDateTime.day);
        DateTime p = DateTime(
            uploadDateTime.year, uploadDateTime.month, uploadDateTime.day - 1);
        DateTime w = DateTime(lastWorkoutDateTime.year, lastWorkoutDateTime.month,
            lastWorkoutDateTime.day);
        if (w == u) {
          log("workout on the same doesn't count");
          // break label;
        }
        else if (w == p) {
          /// this means that this user worked out in a row, so add up streak
          // get streak data
          streak++;
          // update streak data
          userDocRef.set(
            {"streak": streak},
            SetOptions(merge: true),
          );
          log("worked out in a streak!");
        }
        else {
          log("lost streak...");
          userDocRef.set(
            {"streak": 0},
            SetOptions(merge: true),
          );
        }
      }
    }
    // no field value
    else{
      userDocRef.set(
        {"streak": 1, "streakStartDate":uploadTimeStamp},
        SetOptions(merge: true),
      );
    }
    // lastWorkout field value is added at the end

    /// Update SBD-Max
    // create "sbdMax" field under user doc
    // check if today's workout contains "squat", "bench press", "dead lift"
    // if any one of those exercise exist
    // compare with the server value
    // if it is greater than server value, update server value
    // else leave the value
    Map<String, dynamic> userDocData = userDoc.data() as Map<String, dynamic>;

    Map<String, num> currentMaxSBD = findMaxSBD(workout);
    num c_s = currentMaxSBD["Squat"]!;
    num c_b= currentMaxSBD["Bench"]!;
    num c_d = currentMaxSBD["Dead"]!;

    if(userDocData.containsKey("SBD-Max")){
      DocumentSnapshot doc = await userDocRef.get();
      Map<String,dynamic> data = doc.data() as Map<String,dynamic>;
      /// 현재 피곤해서 용어의 대소문자 통일성 없음...
      /// double int 도 통일성 없음... gg
      num s = data["squat"];
      num b = data["bench"];
      num d = data["dead"];
      if(c_s > s){
        s = c_s;
      }
      if(c_b > b){
        b = c_b;
      }
      if(c_d > d){
        d = c_d;
      }
      // otherwise leave unchanged
      await userDocRef.set({"sbd": {"squat": s, "bench": b, "dead": d}}, SetOptions(merge: true));
      num sum = s+b+d;
      await userDocRef.set({"sbdSum": sum}, SetOptions(merge: true));

    }
    else {
      // 처음
      await userDocRef.set({"sbd": {"squat": c_s, "bench": c_b, "dead": c_d}}, SetOptions(merge: true));
      num sum = c_s+c_b+c_d;
      await userDocRef.set({"sbdSum": sum}, SetOptions(merge: true));
    }

    /// Update last workout date (only 1 workout counted per day)
    // create a field "lastWorkout" under user doc
    // after operating all other workout values, update this value to most recent workout date
    log("WS :: updating lastWorkout");
    userDocRef.set(
      {"lastWorkout": uploadTimeStamp},
      SetOptions(merge: true),
    );

    log("------- Workout add completed");
  }

  /// Get workout data of a user once
  /// it downloads all of the user's workout data
  /// currently it download all of the workout data
  /// should modify it to load only the workouts in a given range
  void workoutQueryOnce() {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == null) return;
    log("Trying to get collection of user id: ${uid}");
    userCollectionRef
        .doc(uid)
        .collection("Workout")
        .orderBy('CreateDate', descending: true)
        .get()
        .then(
      (res) {
        // res will contain all of the documents of user collection
        // final data = doc.data() as Map<String, dynamic>;
        /* Fields:
             *      1. <Ex 1>
             *      2. <Ex 2>
             *      3. CreateDate
             */
        _workouts = []; // reset _workouts
        for (DocumentSnapshot doc in res.docs) {
          final data = doc.data() as Map<String, dynamic>;
          List<Exercise> exercises = []; // create exercise list for a workout
          for (final exerciseName in data.keys) {
            if (exerciseName == 'CreateDate') continue;
            // otherwise assume the field is an exercise data
            Exercise exercise = Exercise(exerciseName); // create an exercise
            for (final set in data[exerciseName]) {
              exercise.addSet(set['weight'], set['reps']);
            }
            exercises.add(exercise);
          }
          final createDate = DateTime.fromMillisecondsSinceEpoch(
                  data['CreateDate'].millisecondsSinceEpoch)
              .toLocal()
              .toString();

          final workout = Workout(
            createDate: createDate,
            exercises: exercises,
          );
          /// todayVolume could me null?
          workout.todayVolume = data['todayVolume'];

          _workouts.add(workout);
        }
        log(_workouts.toString());
      },
      onError: (e) => log("Error getting document: $e"),
    );
  }

  /// below function should not be used
  /// NOT COMPLETED function
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      workoutQueryStream() {
    log("Downloading user's workout data from firebase");
    String uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == null) return null;
    String workoutCollectionName = "Workout_${uid}";
    return userCollectionRef
        .doc(uid)
        .collection("Workout")
        .orderBy('CreateDate', descending: true)
        .snapshots()
        .listen((snapshot) {
      _workouts = [];
      log("product change detected!.. there are ${snapshot.docs.length} documents");
      for (final document in snapshot.docs) {
        // _workouts.add();
      }
      notifyListeners();
    });
  }
}
