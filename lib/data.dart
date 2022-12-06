import 'dart:math' as math;
import 'dart:developer';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draw_graph/draw_graph.dart';
import 'package:draw_graph/models/feature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lift/editworkout.dart';
import 'package:lift/model/Workout.dart';
import 'package:lift/state_management/DataState.dart';
import 'package:lift/state_management/WorkoutState.dart';
import 'package:lift/workouttest.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'navigation_bar/bottom_navigation_bar.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

/// should I move this to a provider?
List<DateTime?> dateRange = [];
DateTime startDateForBottomTitle = DateTime(1);

/// for expansion pannel
// stores ExpansionPanel state information
class Item {
  Item({
    required this.expandedValue,
    required this.headerValue,
    this.isExpanded = false,
  });
  String id = const Uuid().v4();
  String expandedValue;
  String headerValue;
  bool isExpanded;
}

List<Item> generateItems(int numberOfItems) {
  return List<Item>.generate(numberOfItems, (int index) {
    return Item(
      headerValue: 'Panel $index',
      expandedValue: 'This is item number $index',
    );
  });
}

class _DataPageState extends State<DataPage> {
  // final List<Item> _data = generateItems(8);
  /// workout days for the month
  List<bool> workoutDays = [true, true, false, true, true];

  /// need to change when page changes
  // List<bool> workoutDays = [true, true, true, false];

  /// USE THIS ONE !
  Widget _buildPanel(DataState dataState) {
    return ExpansionPanelList.radio(
      children: dataState.workouts.map<ExpansionPanelRadio>((Workout workout) {
        return ExpansionPanelRadio(
          canTapOnHeader: true,
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(
                DateFormat("yyyy MMM dd, EEE  hh:mm").format(workout.createDate!),
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
              ),
            );
          },
          body: Column(
            children: [
              ListTile(
                title: Text(
                  workout.toWorkoutOnlyString(),
                  // "adfadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfad",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: null,
                onTap: null,
              ),
              Row(
                // mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    color: Colors.blueAccent,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditWorkOut(editWorkout: workout,),
                        ),
                      );},
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever),
                    color: Colors.redAccent,
                    onPressed: () async {
                      /// delete list tile
                      log("delete pressed!");
                      String uid = FirebaseAuth.instance.currentUser!.uid;
                      // actual deletion should be done lastly
                      // await FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout").doc(workout.docId).delete();

                      /// when deleting workout data, need to subtract from volume
                      // 1. download total volume
                      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance.collection("User").doc(uid).get();
                      num totalVolume = doc.data()!["totalVolume"];
                      log("DELETE ON PROGRESS");
                      // 2. subtract today volume (from data to delete)
                      if(workout.todayVolume != null){
                        totalVolume -= workout.todayVolume!;
                      }
                      else {
                        log("When deleting from data page, workout's todayVolume is null, and so cannot update firebase total volume");
                      }

                      // 3. update the modified total volume
                      await FirebaseFirestore.instance.collection("User").doc(uid).set(
                          {"totalVolume":totalVolume}, SetOptions(merge: true));
                      // totalVolume updated!
                      /// update page
                      // after deleting update the context

                      /// modify streak if deleted workout date is inbetween the streaks
                      /// and if there is no other workout in the selected date
                      // 1. check if there are more than 1 workout in the selected date
                      int year = workout.createDate!.year;
                      int month = workout.createDate!.month;
                      Timestamp editDate = Timestamp.fromDate(workout.createDate!);
                      QuerySnapshot<Map<String, dynamic>> temp = await FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout").where("CreateDate", isEqualTo: editDate).get();
                      log("DOC to delete is of date: ${editDate}\n" +
                      "${temp.docs.isNotEmpty}\n" +
                          "${temp.docs.length}"
                      );
                      if(temp.docs.isNotEmpty || temp.docs.length == 1){
                        log("DELETE ONLY ONE");
                        DocumentSnapshot<Map<String, dynamic>> daysData = await FirebaseFirestore.instance.collection("User").doc(uid).collection("WorkoutDates").doc(year.toString()).get();
                        List<dynamic> monthData = daysData.data()![month.toString()];
                        monthData[workout.createDate!.day - 1] = false;

                        // update WorkoutDays
                        await FirebaseFirestore.instance.collection("User").doc(uid).collection("WorkoutDates").doc(year.toString()).set(
                            {"${month}":monthData}, SetOptions(merge: true));

                        // update Streak
                        // SS = Streak Start date
                        DateTime SS = doc.data()!["streakStartDate"].toDate();
                        DateTime del = workout.createDate!;
                        SS = DateTime(SS.year, SS.month, SS.day);
                        del = DateTime(del.year, del.month, del.day);
                        DateTime lastWorkoutDate = doc.data()!["lastWorkout"].toDate();
                        lastWorkoutDate = DateTime(lastWorkoutDate.year, lastWorkoutDate.month, lastWorkoutDate.day);
                        if(lastWorkoutDate.isAtSameMomentAs(del)){
                          log("DELETE STREAK - same moment");
                          await FirebaseFirestore.instance.collection("User").doc(uid).set({"streak":0, "streakStartDate":FieldValue.delete()}, SetOptions(merge: true));
                        }
                        else if(del.isAfter(SS) || del.isAtSameMomentAs(SS)){
                          log("DELETE STREAK - before last workout");
                          int minusStreak = SS.difference(del).inDays+1;
                          int currentStreak = doc.data()!["streak"];
                          int newStreak = currentStreak - minusStreak;
                          DateTime del_next = DateTime(del.year, del.month, del.day).add(const Duration(days: 1));
                          Timestamp ts_del_next = Timestamp.fromDate(del_next);
                          await FirebaseFirestore.instance.collection("User").doc(uid).set({"streak":newStreak, "streakStartDate":ts_del_next}, SetOptions(merge: true));
                        }
                        // else if(del.isAtSameMomentAs(SS)){
                        //   // streak started today
                        //   // reset streak
                        //   // remove streakStartDate field
                        //   await FirebaseFirestore.instance.collection("User").doc(uid).set({"streak":0, "streakStartDate":FieldValue.delete()}, SetOptions(merge: true));
                        // }
                      }
                      log("DELETE SUCESS");

                      // actual delete
                      await FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout").doc(workout.docId).delete();

                      await dataState.reloadDataAndWorkouts();
                    },
                    // onPressed: () async {
                    //   /// delete list tile
                    //   log("delete pressed!");
                    //   String uid = FirebaseAuth.instance.currentUser!.uid;
                    //   await FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout").doc(workout.docId).delete();
                    //   log("delete success!");
                    //
                    //   // after deleting update the context
                    //   await dataState.reloadDataAndWorkouts();
                    // },
                  ),
                ],
              )
            ],
          ),
          value: const Uuid().v4(),
        );
      }).toList(),
    );
  }

  /// This one is not used!
  List<ExpansionTile> _buildPanel2(DataState dataState) {
    return dataState.workouts.map<ExpansionTile>((Workout workout) {
      return ExpansionTile(
        title: Text(
          DateFormat("yyyy MMM dd, EEE  hh:mm").format(workout.createDate!),
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
        ),
        children: <Widget>[
          ListTile(
            title: Text(
              workout.toWorkoutOnlyString(),
              // "adfadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfadadadfad",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: null,
            onTap: null,
          ),
          Row(
            // mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                color: Colors.blueAccent,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditWorkOut(editWorkout: workout,),
                    ),
                  ).then((value) => setState( (){}));
                  /// goto edit page
                  ///
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever),
                color: Colors.redAccent,
                onPressed: () async {
                  /// delete list tile
                  log("delete pressed!");
                  String uid = FirebaseAuth.instance.currentUser!.uid;
                  await FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout").doc(workout.docId).delete();
                  log("delete success!");

                  /// when deleting workout data, need to subtract from volume
                  // 1. download total volume
                  DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance.collection("User").doc(uid).get();
                  num totalVolume = doc.data()!["totalVolume"];
                  // 2. subtract today volume (from data to delete)
                  if(workout.todayVolume != null){
                    totalVolume -= workout.todayVolume!;
                  }
                  else {
                    log("When deleting from data page, workout's todayVolume is null, and so cannot update firebase total volume");
                  }

                  // 3. update the modified total volume
                  await FirebaseFirestore.instance.collection("User").doc(uid).set(
                      {"totalVolume":totalVolume}, SetOptions(merge: true));
                  // totalVolume updated!
                  /// update page
                  // after deleting update the context

                  /// modify streak if deleted workout date is inbetween the streaks
                  /// and if there is no other workout in the selected date
                  // 1. check if there are more than 1 workout in the selected date
                  int year = workout.createDate!.year;
                  int month = workout.createDate!.month;
                  Timestamp editDate = Timestamp.fromDate(workout.createDate!);
                  QuerySnapshot<Map<String, dynamic>> temp = await FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout").where("CreateDate", isEqualTo: editDate).get();

                  if(temp.docs.isNotEmpty || temp.docs.length == 1){
                    DocumentSnapshot<Map<String, dynamic>> daysData = await FirebaseFirestore.instance.collection("User").doc(uid).collection("WorkoutDates").doc(year.toString()).get();
                    List<bool> monthData = daysData.data()![month];
                    monthData[workout.createDate!.day - 1] = false;

                    // update WorkoutDays
                    await FirebaseFirestore.instance.collection("User").doc(uid).collection("WorkoutDates").doc(year.toString()).set(
                        {"${month}":monthData}, SetOptions(merge: true));

                    // update Streak
                    // SS = Streak Start date
                    DateTime SS = doc.data()!["streakStartDate"].toDate();
                    DateTime del = workout.createDate!;
                    SS = DateTime(SS.year, SS.month, SS.day);
                    del = DateTime(del.year, del.month, del.day);
                    if(del.isAfter(SS)){
                      int minusStreak = SS.difference(del).inDays;
                      int currentStreak = doc.data()!["streak"];
                      int newStreak = currentStreak - minusStreak;
                      DateTime del_next = DateTime(del.year, del.month, del.day).add(const Duration(days: 1));
                      Timestamp ts_del_next = Timestamp.fromDate(del_next);
                      await FirebaseFirestore.instance.collection("User").doc(uid).set({"streak":newStreak, "streakStartDate":ts_del_next}, SetOptions(merge: true));
                    }
                  }
                  await dataState.reloadDataAndWorkouts();
                },
              ),
            ],
          )

        ],
      );
    }).toList();
  }


  /// need to initialize above values to data past 7 days at init
  @override
  Widget build(BuildContext context) {
    DataState simpleDataState = Provider.of<DataState>(context, listen: false);
    WorkoutState simpleWorkoutState = Provider.of<WorkoutState>(context, listen: false);

    const dayTextStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.w700);
    final weekendTextStyle = TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600);
    final anniversaryTextStyle = TextStyle(
      color: Colors.red[400],
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    CalendarDatePicker2WithActionButtonsConfig config(workoutDays) => CalendarDatePicker2WithActionButtonsConfig(
        // firstDate: DateTime.now(),
        dayTextStyle: dayTextStyle,
        calendarType: CalendarDatePicker2Type.range,
        selectedDayHighlightColor: Colors.lightBlueAccent,
        closeDialogOnCancelTapped: true,
        firstDayOfWeek: 0,  /// starting sunday
        weekdayLabelTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        controlsTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        selectedDayTextStyle: dayTextStyle.copyWith(color: Colors.white),
        dayTextStylePredicate: ({required date}) {
          TextStyle? textStyle;
          if (date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday) {
            textStyle = weekendTextStyle;
          }
          if (date.month == 12 && date.day == 25) {
            textStyle = anniversaryTextStyle;
          }
          return textStyle;
        },
        dayBuilder: ({
          required date,
          textStyle,
          decoration,
          isSelected,
          isDisabled,
          isToday,
        }) {
          Widget? dayWidget;
          /// get workout dates
          if (date.day <= workoutDays.length && workoutDays[date.day-1] == true) {
            dayWidget = Container(
              decoration: decoration,
              child: Center(
                child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: [
                    Text(
                      MaterialLocalizations.of(context).formatDecimal(date.day),
                      style: textStyle,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 27.5),
                      child: Container(
                        height: 4,
                        width: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: isSelected == true
                              ? Colors.white
                              : Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return dayWidget;
        });


    return Scaffold(
      appBar: AppBar(
        title: Text("Data"),
      ),
      body: SafeArea(
          child: ListView(

        physics: const ScrollPhysics(),
        shrinkWrap: true,
        primary: true,
        children: [
          // 1. Calendar
          Consumer<DataState>(
            builder: (context, dataState, widget) => CalendarDatePicker2(
              config: config(dataState.workoutDays),
              onValueChanged: (dates) async {
                // Selecting date will trigger screen rebuild
                // re-building screen will cause the selected date to disappear
                // therefore can't use setState() in here
                // setState(() {});
                dateRange = dates;
                log("DATA :: ${dateRange.toString()}");
                /// must select 2 dates to display Graph
                /// and the two dates must not be the same
                if(dateRange.length == 2 && !dates.first!.isAtSameMomentAs(dates.last!)){
                  log("Do work");
                  startDateForBottomTitle = dateRange.first!;
                  simpleDataState.updateData(dateRange.first!, dateRange.last!);

                  simpleDataState.updateWorkouts(dateRange.first!, dateRange.last!);
                }
                else{
                  dataState.date1 = dates.first!;
                  dataState.date2 = null;
                }
              },
              onDisplayedMonthChanged: (date) async {
                /// need to preserve previously selected data
                await simpleDataState.updateWorkoutDays(date);
              },

              /// initial value should be past 7 days from today
              /// get today from phone time
              // initialValue: [simpleDataState.date1, simpleDataState.date2],
              initialValue: [dataState.date1, dataState.date2],
            ),
          ),
          // 2. Graph
          /*
          Padding(
            padding: EdgeInsets.all(10),
            child: Consumer<WorkoutState>(
              builder: (BuildContext context, workoutState, Widget? child) {
                /**
                   * range는 오늘을 포함해서 가져올 최대 과거 날짜를 의미한다
                   */
                int range = 7;
                /**
                   * Graph와 관련된 List는 과거->현재 순으로 데이터가 들어가 있어야 한다
                   */
                List<double> data = [];
                List<String> labelX = []; // date
                List<String> labelY = []; // volume

                DateTime now = DateTime.now();

                double maxVolume = 0;
                for (int i = range - 1; i >= 0; i--) {
                  DateTime date = DateTime(now.year, now.month, now.day - i);
                  final dateString = DateFormat("yyyy-MM-dd").format(date);
                  labelX.add(
                      DateFormat('M/d').format(date).replaceAll('/', '/\n'));
                  double volumeAtDate =
                      workoutState.getTotalVolumeAtDate(dateString);
                  data.add(volumeAtDate);
                  maxVolume = math.max(volumeAtDate, maxVolume);
                }
                for (int i = 1; i <= data.length; i++) {
                  double number = (maxVolume * (0.2 * i));
                  if (number >= 1000) {
                    number /= 1000;
                    /**
                       * totalVolume은 뒤에 K를 붙여 1000단위로 보여준다
                       */
                    labelY.add("${number.toStringAsPrecision(2)}K");
                  } else {
                    labelY.add("${number.toInt()}");
                  }
                }
                // normalize data
                for (int i = 0; i < data.length; i++) {
                  data[i] /= maxVolume;
                }
                // log("length of labelY [] is ${data.length}");

                // final totalVolumeOfDay = workoutState.workouts.
                // Timestamp.now() < Timestamp.fromDate(DateTime.parse(formattedString))

                return LineGraph(
                  features: [
                    Feature(
                      title: "Total Volume",
                      color: Colors.deepPurpleAccent,
                      data: data,
                    ),
                  ],
                  size: Size(400, 400),
                  labelX: labelX,
                  labelY: labelY,
                  showDescription: true,
                  graphColor: Colors.black,
                  graphOpacity: 0.2,
                  verticalFeatureDirection: true,
                  descriptionHeight: 130,
                );
              },
            ),
          ),
          */
          // 2.5 Graph 2
          Text(" Graph - volume", style: TextStyle(fontSize: 30),),
          AspectRatio(
            aspectRatio: 1.5,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(18),
                ),
                /// background color
                color: Color(0xfff3f6f4),
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 18,
                  left: 12,
                  top: 24,
                  bottom: 12,
                ),
                /// This is where Graph widget is called
                child: Consumer<DataState>(
                  builder: (context, dataState, widget) =>
                    LineChart(
                      mainData(
                          dataState.data,
                          dataState.startDate,
                          dataState.maxY,
                          dataState.maxX
                      ),
                    ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(" Workouts", style: TextStyle(fontSize: 30),),
          SizedBox(height: 20),
          // 3. Exercise
          /// Display workout data
          // Consumer<DataState>(
          //   builder: (context, dataState, widget) => _buildPanel(dataState),
          // ),
          // Text("test"),Text("test"),Text("test"),
          Consumer<DataState>(
            /// Column으로 해서 안에 Expansion tile들을 담으면 된다
            builder: (context, dataState, widget) => Column(
              children :[
                _buildPanel(dataState),
  ],
            ) ,
          ),
        ],
      )),
      bottomNavigationBar: BNavigationBar(),
    );
  }

}

/// can be customized later
List<Color> gradientColors = [
  const Color(0xff23b6e6),
  const Color(0xff02d375),
];

LineChartData mainData(List<FlSpot> data, DateTime startDate, double maxY, double maxX) {
  maxX -= 1;
  /// need to get data, startDate, max Y, and max X as parameter
  /// Y = volume
  // double maxY = 23.0;
  int hLines = 5;
  /// X = days
  /// should not have decimal value
  // double maxX = 128.0;  // 100일 동안의 기록
  int maxVLines = 10;
  double vLineInterval = 1;

  double minY = 100;
  if(maxY < minY) {
    maxY = minY;
  }

  /// 아래 코드는 지금 원하는 대로 안나온다
  /// 로직을 다시 생각해 봐야된다
  if(maxX < maxVLines) {
    vLineInterval = 1;
  }
  else {
    int remainder = (maxX % maxVLines).toInt();
    if(remainder!= 0) {
      if(remainder < 5){
        // I don't want the spacing to be too small
        int remainder2 = (maxX % (maxVLines-1)).toInt();
        vLineInterval = (maxX + ((maxVLines-1)-remainder2))/(maxVLines-1);
      }
      else {
        vLineInterval = (maxX + (maxVLines-remainder))/maxVLines;
      }
    }
    else{
      vLineInterval = maxX/maxVLines;
    }
  }

  log("vLineInterval : $vLineInterval");
  log("maxX : $maxX");
  log("^^^^^^^^^^^^^ $startDate ^^^^^^^^^^^^^^");
  startDateForBottomTitle = startDate;


  // display all values if days is less than 10
  // however date is discrete


  return LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: true,
      /// line drawing interval
      horizontalInterval: maxY/hLines,
      verticalInterval: vLineInterval,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: const Color(0xffbcbcbc),
          strokeWidth: 1,
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: const Color(0xffbcbcbc),
          strokeWidth: 1,
        );
      },
    ),
    titlesData: FlTitlesData(
      show: true,
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40, /// don't need to change this
          /// bottom title interval is defined here
          interval: vLineInterval,
          getTitlesWidget: bottomTitleWidgets,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: maxY/hLines,
          /// side title
          getTitlesWidget: leftTitleWidgets,
          reservedSize: 42, /// no need to change this
        ),
      ),
    ),
    borderData: FlBorderData(
      show: true,
      /// grid color
      border: Border.all(color: const Color(0xff37434d)),
    ),
    /// data setting
    minX: 0, /// min data is always 0
    /// Number of bottom width is defined here
    maxX: maxX, /// maximum width of x (not related to the value of x, but related to size of x)
    minY: 0, /// min y is always 0
    maxY: maxY, /// maximum height of y (not related to the value of y)
    /// make maxY fixed so the user can have good experience
    /// All y values should be normalized and multiplied by 5
    lineBarsData: [
      /// return data
      LineChartBarData(
        spots: data,  /// actual data
        /// curve로 하면 중간 지점들이
        isCurved: true,
        preventCurveOverShooting: true,
        gradient: LinearGradient(
          colors: gradientColors,
        ),
        barWidth: 3.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: false,
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: gradientColors
                .map((color) => color.withOpacity(0.3))
                .toList(),
          ),
        ),
      ),
    ],
  );
}

Widget bottomTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(
    /// text color
    color: Color(0xff444444),
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );
  Widget text;

  /// global startDate
  DateTime thisDate = startDateForBottomTitle.add(Duration(days: value.toInt()));
  text = Text("${thisDate.month}/\n${thisDate.day}");
  String dateString = "";
  switch (thisDate.month) {
  case 1:
    dateString += "JAN";
    break;
  case 2:
    dateString += "FEB";
    break;
  case 3:
    dateString += "MAR";
    break;
  case 4:
    dateString += "APR";
    break;
  case 5:
    dateString += "MAY";
    break;
  case 6:
    dateString += "JUN";
    break;
  case 7:
    dateString += "JUL";
    break;
  case 8:
    dateString += "AUG";
    break;
  case 9:
    dateString += "SEP";
    break;
  case 10:
    dateString += "OCT";
    break;
  case 11:
    dateString += "NOV";
    break;
  case 12:
    dateString += "DEC";
    break;
  default:
    dateString += "???";
    break;
  }

  dateString += "\n  ";
  dateString += thisDate.day.toString();

  text = Text(dateString, style: style);

  return SideTitleWidget(
    axisSide: meta.axisSide,
    child: text,
  );
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(
    /// text color
    color: Color(0xff444444),
    fontWeight: FontWeight.bold,
    fontSize: 15,
  );
  String text;
  if(value<1000){
    return Text(value.toStringAsFixed(1), style: style, textAlign: TextAlign.left);
  }
  else {
    return Text("${(value/1000).toStringAsFixed(1)}K", style: style, textAlign: TextAlign.left);
  }
  switch (value.toInt()) {
    case 1:
      /// set text according to the actual maximum value of y
    /// need to get it from external variable
    /// can't pass value through parameter..?
      text = '10K';
      break;
    case 3:
      text = '30k';
      break;
    case 5:
      text = '50k';
      break;
    default:
      // return const Text('a', style: style);
      return Container();
  }

  return Text(text, style: style, textAlign: TextAlign.left);
}

Future<List<FlSpot>> getDataBetweenDates(DateTime date1, DateTime date2) async {
  /// date1 -> date2
  List<FlSpot> chartData = <FlSpot>[];
  /// directly connect to firebase from here
  /// caller of this method should assign local variable inside setState()
  log("date 1 is : ${date1.toString()}");
  log("date 2 is : ${date2.toString()}");
  int dateDistance = date2.difference(date1).inDays + 1;
  log("Date distance is : $dateDistance");
  for(double i=0; i<dateDistance; i++) {
    /// initialize all data at date to 0
    chartData.add(FlSpot(i, 0));
  }

  String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  CollectionReference<Map<String, dynamic>> workoutColRef = FirebaseFirestore.instance.collection("User").doc(uid).collection("Workout");
  /// date2 까지의 정보를 원하기 때문에
  /// date2 + 1 day를 해주고 lessThan으로 query한다
  date2 = date2.add(Duration(days: 1));
  Query<Map<String, dynamic>> betweenDateQuery = workoutColRef.where("CreateDate", isGreaterThanOrEqualTo: date1).where("CreateDate", isLessThan: date2);
  // query is ordered by "todayVolume" in descending order
  // this means that max value is at top
  QuerySnapshot<Map<String, dynamic>> querySnapshot = await betweenDateQuery.get();


  /// what if queried data is over 10000 days or like such great number
  /// need to wait too long?
  /// might want to limit the maximum allowed query dates
  num maxVolume = 0;
  for(QueryDocumentSnapshot<Map<String, dynamic>> doc in querySnapshot.docs){
    Map<String, dynamic> data = doc.data();
    // check index position of the date of the found data
    Timestamp thisDate = data["CreateDate"] as Timestamp;
    log("@@ data at : ${thisDate.toDate().toString()}");
    // 운동 생성 날짜 - 시작 날짜 = 운동 그래프 위치
    int dateIndex = (thisDate.toDate()).difference(date1).inDays;
    // need to get total volume at specific date
    num todayVolume = data["todayVolume"];
    // first data has the max value
    if(maxVolume == 0) {
      maxVolume = todayVolume;
    }
    // double normalizedVolume = todayVolume/maxVolume;
    // double scale = 5.0;
    /// don't need to normalize
    // todayVolume should be normalized using max value and multiplied by 5
    chartData[dateIndex] = FlSpot(dateIndex.toDouble(), todayVolume.toDouble());
  }
  // FlSpot(0, 3)
  return chartData;
}












