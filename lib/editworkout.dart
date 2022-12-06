import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lift/model/Exercise.dart';
import 'package:lift/model/Workout.dart';
import 'package:lift/state_management/DataState.dart';
import 'package:lift/state_management/NavigationState.dart';
import 'package:lift/state_management/WorkoutState.dart';
import 'package:msh_checkbox/msh_checkbox.dart';
import 'package:provider/provider.dart';

import 'navigation_bar/bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EditWorkOut extends StatefulWidget {
  final Workout editWorkout;
  const EditWorkOut({required this.editWorkout});

  @override
  State<EditWorkOut> createState() => _EditWorkOut();
}

class _EditWorkOut extends State<EditWorkOut> {
  List< List<TextEditingController> > weightcontrol = [];
  List< List<TextEditingController> > repscontrol = [];
  List< List<bool> > workoutDone = [];
  Workout workEditing = Workout();

  int count = 0;
  final addWorkout = TextEditingController();


  List<Widget> _buildSet(Exercise exercise, List<TextEditingController> weightControl, List<TextEditingController> repsControl, List<bool> workoutCheck){
    print("wieghtControl length = ${weightControl.length}, repsControl length = ${repsControl.length}");
    int count = 0;
    if (exercise.Sets.isEmpty) {
      return const <Row>[];
    }
    return exercise.Sets.map((set){
      return Column(
        children: [
          SizedBox(height: 8,),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("${++count}"),
              SizedBox(
                width: 70,
                height: 30,
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  controller: weightControl[count-1],
                  decoration: InputDecoration(
                    labelText: "kg",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                height: 30,
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  controller: repsControl[count-1],
                  decoration: InputDecoration(
                    labelText: "reps",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              MSHCheckbox(
                size: 35,
                value: workoutCheck[exercise.Sets.indexOf(set)],
                colorConfig: MSHColorConfig.fromCheckedUncheckedDisabled(
                  checkedColor: Colors.blue,
                ),
                style: MSHCheckboxStyle.stroke,
                onChanged: (selected) {
                  setState(() {
                    workoutCheck[exercise.Sets.indexOf(set)] = selected;
                    if(selected){
                      print(workoutCheck[exercise.Sets.indexOf(set)].toString());
                      set['weight'] = int.parse(weightControl[exercise.Sets.indexOf(set)].text); //Exercise에 index 추가해야함
                      set['reps'] = int.parse(repsControl[exercise.Sets.indexOf(set)].text);//Exercise에 index 추가해야함
                    }else{
                      set['weight'] = 0; //Exercise에 index 추가해야함
                      set['reps'] = 0;//Exercise에 index 추가해야함
                    }
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 7,)
        ],
      );
    }).toList();
  }//운동별 세트

  List<Widget> _buildCards(BuildContext context) {
    if (workEditing.exercises.isEmpty) {
      return const <Card>[];
    }

    return workEditing.exercises.map((exercise) {
      return Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)
            ),
            elevation: 6.0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                          onPressed: () => showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              scrollable: true,
                              title: Text('${exercise.Name}'),
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Work Out Name: ${exercise.Name}'),
                                  SizedBox(height: 10,),
                                  MaterialButton( //search on color
                                    shape: OutlineInputBorder(
                                      borderRadius: new BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Color(0xFF545454)),
                                    ),
                                    onPressed: () {},
                                    child: Container(
                                      child: RichText(
                                        text: const TextSpan(children:[
                                          TextSpan(
                                            text: 'Search on ',
                                            style: TextStyle(color: Color(0xFF9B9B9B)),
                                          ),
                                          TextSpan(
                                            text: 'G',
                                            style: TextStyle(color: Color(0xFF176BEF)),
                                          ),
                                          TextSpan(
                                            text: 'o',
                                            style: TextStyle(color: Color(0xFFFF3E30)),
                                          ),
                                          TextSpan(
                                            text: 'o',
                                            style: TextStyle(color: Color(0xFFF7B529)),
                                          ),
                                          TextSpan(
                                            text: 'g',
                                            style: TextStyle(color: Color(0xFF176BEF)),
                                          ),
                                          TextSpan(
                                            text: 'l',
                                            style: TextStyle(color: Color(0xFF129C52)),
                                          ),
                                          TextSpan(
                                            text: 'e',
                                            style: TextStyle(color: Color(0xFFFF3E30)),
                                          ),
                                        ]
                                        ),//google with color
                                      ),
                                    ), //search google pretty colors
                                  ),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(context, 'OK'),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ),
                          icon: Icon(Icons.info_outline)),
                      Text(exercise.Name),
                      IconButton(
                          onPressed: (){
                            setState(() {
                              // weightcontrol[workEditing.exercises.indexOf(exercise)].clear();
                              // repscontrol[workEditing.exercises.indexOf(exercise)].clear();
                              // workoutDone[workEditing.exercises.indexOf(exercise)].clear();
                              weightcontrol.removeAt(workEditing.exercises.indexOf(exercise));
                              repscontrol.removeAt(workEditing.exercises.indexOf(exercise));
                              workoutDone.removeAt(workEditing.exercises.indexOf(exercise));
                              workEditing.exercises.remove(exercise);
                            });
                          },
                          icon: Icon(CupertinoIcons.trash)),
                    ],
                  ),//top part
                  Divider(thickness: 2,),
                  SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text("set"), Text("kg"), Text("reps"), Text("done"),
                    ],
                  ), //number weight reps check buttons
                  Column(
                    children: _buildSet(exercise, weightcontrol[workEditing.exercises.indexOf(exercise)], repscontrol[workEditing.exercises.indexOf(exercise)], workoutDone[workEditing.exercises.indexOf(exercise)]),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      MaterialButton(
                        shape: OutlineInputBorder(
                            borderRadius: new BorderRadius.circular(12)
                        ),
                        onPressed: () {
                          setState(() {
                            weightcontrol[workEditing.exercises.indexOf(exercise)].removeLast();
                            repscontrol[workEditing.exercises.indexOf(exercise)].removeLast();
                            workoutDone[workEditing.exercises.indexOf(exercise)].removeLast();
                            exercise.Sets.removeLast();
                          });
                        },
                        child: Text(
                          "--set",
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),

                      ),//--set
                      MaterialButton(
                        shape: OutlineInputBorder(
                            borderRadius: new BorderRadius.circular(12)
                        ),
                        onPressed: () {
                          setState(() {
                            exercise.addSet(0, 0);
                            weightcontrol[workEditing.exercises.indexOf(exercise)].add(TextEditingController(text: "0"));
                            repscontrol[workEditing.exercises.indexOf(exercise)].add(TextEditingController(text: "0"));
                            workoutDone[workEditing.exercises.indexOf(exercise)].add(false);
                            // print(workoutDone.toString());
                          });
                        },
                        child: Text(
                          "++set",
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                      ),//++set
                    ],
                  )//++set--
                ],
              ),
            ),
          ),
          SizedBox(height: 20,)
        ],
      );
    }).toList();
  }//운동 이름

  @override
  Widget build(BuildContext context) {
    WorkoutState _workout = Provider.of<WorkoutState>(context);
    DataState _datastate = Provider.of<DataState>(context, listen: false);

    if(count == 0) {
      count++;
      int index = 0;
      workEditing.exercises = List.from(widget.editWorkout.exercises);
      workEditing.docId = widget.editWorkout.docId;
      workEditing.createDate = widget.editWorkout.createDate;

      for (var element in widget.editWorkout.exercises) {
        List<TextEditingController> newcontrol = [];
        List<TextEditingController> newcontrol2 = [];
        List<bool> newcontrol3 = [];
        weightcontrol.add(newcontrol);
        repscontrol.add(newcontrol2);
        workoutDone.add(newcontrol3);

        for (var setElement in element.Sets) {
          weightcontrol[index].add(TextEditingController(text: setElement["weight"].toString()));
          repscontrol[index].add(TextEditingController(text: setElement["reps"].toString()));
          workoutDone[index].add(true);
        }
        index++;
      }

      print("weightcontrol: " + weightcontrol.toString());
      print("\n\nrepscontrol: " + repscontrol.toString());
      print("\n\nworkoutDone: " + workoutDone.toString());
    }

    // log(workout.exercises.toString());
    // log(weightcontrol.toString());
    // BNavigationBar nevi =

    // List<Widget> squatrow = new List.generate(_squatset, (int i) => new ContactRow());

    return Scaffold(
      appBar: AppBar(
        title: Text("edit work out"),
        // leading: ,
        elevation: 6.0,
      ),
      body: ListView(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(height: 20),
                Column(
                  children: _buildCards(context),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MaterialButton(
                      color: Colors.grey[200],
                      shape: OutlineInputBorder(
                          borderRadius: new BorderRadius.circular(12)
                      ),
                      onPressed: () => showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          scrollable: true,
                          title: Text('Add Workout'),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exercise Name: '),
                              SizedBox(height: 10,),
                              TextField(
                                controller: addWorkout,
                              )
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                // dispose();
                                addWorkout.clear();
                                Navigator.pop(context, 'CANCEL');
                              },
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  workEditing.exercises.add(Exercise(addWorkout.text));
                                  List<TextEditingController> newcontrol = [];
                                  List<TextEditingController> newcontrol2 = [];
                                  weightcontrol.add(newcontrol);
                                  repscontrol.add(newcontrol2);

                                  List<bool> newcontrol3 = [];
                                  workoutDone.add(newcontrol3);

                                  addWorkout.clear();
                                });
                                Navigator.pop(context, 'ADD');
                              },
                              child: const Text('ADD'),
                            ),
                          ],
                        ),
                      ),
                      child: Text(
                        "ADD WORKOUT",
                        style: TextStyle(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Text(" | ", style: TextStyle(fontSize: 25),),
                    MaterialButton(
                      color: Colors.blue,
                      shape: OutlineInputBorder(
                          borderRadius: new BorderRadius.circular(12)
                      ),
                      onPressed: () async{
                        setState(() {
                          if (workEditing.exercises.isEmpty) {
                            print("운동을 추가하시오");
                            return;
                          }

                          print(workEditing.toString());
                          print("\n\n\n"+widget.editWorkout.toString());
                          // _workout.addWorkout(workEditing);
                          _workout.editWorkout(widget.editWorkout, workEditing);
                          print("done");

                          workEditing.exercises.clear();
                          weightcontrol.clear();
                          repscontrol.clear();
                          workoutDone.clear();


                        });
                        DateTime startDate = _datastate.date1;
                        DateTime? now = _datastate.date2;

                        await _datastate.initData();
                        await _datastate.updateWorkoutDays(startDate);
                        if(now != null) {
                          await _datastate.updateWorkouts(startDate, now);
                        }

                        await _datastate.reloadDataAndWorkouts();

                        print("working");
                        
                        // Navigator.of(context).popUntil((route) => false);
                        Navigator.popUntil(context, ModalRoute.withName('/'));
                        Navigator.pushNamed(context, '/datapage');


                        // Navigator.of(context).popAndPushNamed('/datapage');
                      },
                      child: Text(
                        "Edit",
                        style: TextStyle(
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                )//bottom buttons
              ],
            ),
          ]
      ),
      bottomNavigationBar: BNavigationBar(),
    );
  }
}
