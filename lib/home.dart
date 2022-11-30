import 'dart:developer';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift/state_management/ApplicationState.dart';
import 'package:lift/state_management/GalleryState.dart';
import 'package:lift/state_management/NavigationState.dart';
import 'package:lift/state_management/WorkoutState.dart';
import 'package:local_hero/local_hero.dart';
import 'package:provider/provider.dart';

import 'model/Workout.dart';
import 'navigation_bar/bottom_navigation_bar.dart';
import 'package:flutter/material.dart';

import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 실시간 업데이트 하지 말고 그냥 페이지가 새로 만들어질 때 자료 받아오기
  // 페이지가 새로 만들어질 때 마다 gallery는 아래 코드로 인해 reset된다
  // 그래서 결국 Gallery 정보는 Provider로 빼주기로 했다
  // 이렇게 하면 나중에 언제 Gallery 정보를 업데이트 하는지에 대한 control도 쉬울것이다
  // List<Map<String, dynamic>> gallery = [];

  /// 여기서 gallery 정보를 다시 읽어 오도록 하면 gallery가 업데이트 되면서
  /// 페이지가 rebuild되어 다시 또 정보를 읽어오고
  /// 무한 루프가 되어서
  /// bottom_navigation_bar 에서 homePage로 이동할 때
  /// Gallery에서 정보를 새로 읽어오도록 설정했다.

  List<StatelessWidget> _buildGridCards(
      BuildContext context, List<Map<String, dynamic>> gallery) {
    final ThemeData theme = Theme.of(context);

    if (gallery.isEmpty) {
      log("HOME :: Gallery is empty");
      return const <StatelessWidget>[];
    }

    return gallery.map((Map<String, dynamic> item) {
      final imgUrl = item["imageUrl"].toString();
      final memo = item["memo"].toString();
      final timeCreated = item["timeCreated"].toDate().toString();
      final timeModified = item["timeModified"].toDate().toString();

      /// there might be case where imageUrl value doesn't exist or
      /// link is dead and cannot retrieve the image
      /// in this case, use default image
      return Card(
        clipBehavior: Clip.antiAlias,
        // TODO: Adjust card heights (103)
        child: InkWell(
          onTap: () async {
            // Navigator.of(context).push(
            //     PageRouteBuilder(
            //         opaque: false,
            //         barrierDismissible:true,
            //         pageBuilder: (BuildContext context, _, __) {
            //           return Dialog(
            //             child: Hero(
            //               tag: imgUrl,
            //               child: CachedNetworkImage(imageUrl: imgUrl,),
            //             ),
            //           );
            //         }
            //     )
            // );
            // // TODO: Display image detail in a popup (?)
            // // TODO: maybe use HeroAnimation
            /// Hero animation can only be used between page routes
            /// Tried LocalHero but failed
            // timeCreated
            await showDialog(
              context: context,
              builder: (_) => Hero(
                tag: imgUrl,
                child: ImageDialog(
                  imgUrl: imgUrl,
                  memo: memo,
                  createDate: timeCreated,
                ),
              ),
            );
            // log("HOME :: Image tapped!");
          },
          splashColor: Colors.blue,
          child: Hero(
            tag: imgUrl,
            child: CachedNetworkImage(
              imageUrl: imgUrl,
              imageBuilder: (context, imageProvider) {
                return Ink.image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  onImageError: (Object, StackTrace) {
                    log("HOME :: no image");
                  },
                );
              },
              placeholder: (context, url) => SizedBox(
                width: 10,
                height: 10,
                child: Center(child: CircularProgressIndicator()),
              ),

              /// if no image is found -> display error icon
              errorWidget: (context, url, error) => Icon(Icons.error),
            ),
          ),
        ),
        // Stack(
        //   children: [
        //     Column(
        //       // TODO: Center items on the card (103)
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: <Widget>[
        //         // AspectRatio(
        //         //   aspectRatio: 15 / 15,
        //         //   child: Image.network(
        //         //     imgUrl,
        //         //     fit: BoxFit.cover,
        //         //   ),
        //         // ),
        //         // Expanded(
        //         //   child: Padding(
        //         //     padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
        //         //     child: Column(
        //         //       // TODO: Align labels to the bottom and center (103)
        //         //       crossAxisAlignment: CrossAxisAlignment.start,
        //         //       // TODO: Change innermost Column (103)
        //         //       children: <Widget>[
        //         //         // TODO: Handle overflowing labels (103)
        //         //         Text(
        //         //           timeCreated,
        //         //           style: theme.textTheme.headline6,
        //         //           maxLines: 1,
        //         //         ),
        //         //         const SizedBox(height: 8.0),
        //         //         Text(
        //         //           "hi",
        //         //           style: theme.textTheme.subtitle2,
        //         //         ),
        //         //       ],
        //         //     ),
        //         //   ),
        //         // ),
        //       ],
        //     ),
        //     // Container(
        //     //   alignment: Alignment.bottomRight,
        //     //   child: TextButton(
        //     //     onPressed: () {
        //     //       // simpleAppState.currentProduct = product;
        //     //       // Navigator.of(context).pushNamed('/detail');
        //     //     },
        //     //     child: const Text("more"),
        //     //   ),
        //     // ),
        //     // Visibility(
        //     //   visible: true,
        //     //   child: Container(
        //     //     alignment: Alignment.topRight,
        //     //     child: const Padding(
        //     //       padding: EdgeInsets.all(5),
        //     //       child: Icon(
        //     //         Icons.check_circle,
        //     //         color: Colors.blueAccent,
        //     //       ),
        //     //     ),
        //     //   ),
        //     // ),
        //   ],
        // ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    /// 패이지가 로드 될 때마다 Firebase에서 데이터를 읽어 온다
    /// 이렇게 하면 Firebase를 사용해 값이 없데이트 되었을 때에도 build를 다시 하기 때문에
    /// build가 무한 반복으로 실행된다
    /// 따라서 결국 Gallery는 외부로 빼주는게 좋다는 결론
    WorkoutState simpleWorkoutState = Provider.of<WorkoutState>(context, listen: false,);
    return Scaffold(
      appBar: AppBar(
        title: Text("home"),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
              icon: Icon(Icons.person)),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 20,
          ),
          ElevatedButton(
            onPressed: () {
              log(FieldValue.serverTimestamp().toString());
              log(Timestamp.now().toString());
              // Provider.of<WorkoutState>(context, listen: false).addWorkout(Workout());
            },
            child: Text("Test Button"),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Workout Streak",
                style: TextStyle(fontSize: 30),
              ),
              Text(
                "${simpleWorkoutState.streak}",
                style: TextStyle(fontSize: 30),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/posedemo');
            },
            child: Text("Pose Detection"),
          ),
          Container(
            color: Colors.lightBlue,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 0),
              child: HeatMap(
                // need to get the dataset from provider?
                // fixed fill color value
                datasets: simpleWorkoutState.currentYearWorkoutDates,
                colorMode: ColorMode.opacity,
                showText: false,
                scrollable: true,
                showColorTip: false, // don't show color range tip
                colorsets: {
                  1: Colors.red,
                  3: Colors.orange,
                  5: Colors.yellow,
                  7: Colors.green,
                  9: Colors.blue,
                  11: Colors.indigo,
                  13: Colors.purple,
                },
                onClick: (value) {
                  // 날짜 클릭 했을 때
                  // ScaffoldMessenger.of(context)
                  //     .showSnackBar(SnackBar(content: Text(value.toString())));
                },
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Gallery",
                style: TextStyle(fontSize: 30),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/addImagePage');
                },
                child: Text("addImage"),
              ),
            ],
          ),
          Consumer<GalleryState>(
            builder: (context, galleryState, _) => GridView.count(
              shrinkWrap: true,
              physics: ScrollPhysics(),
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16.0),
              childAspectRatio: 8.0 / 9.0,

              /// galleryState.gallery is automatically updated when notifyListeners() is called at the Provider side
              children: _buildGridCards(context, galleryState.gallery),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BNavigationBar(),
    );
  }
}

class ImageDialog extends StatelessWidget {
  const ImageDialog({super.key, this.imgUrl, this.memo, this.createDate});
  final imgUrl;
  final memo;
  final createDate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      /// shape not working
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2.0))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          SizedBox(
            height: 300,
            width: double.infinity,
            child: CachedNetworkImage(
              fit: BoxFit.cover,
              imageUrl: imgUrl,
            ),
          ),
          Text(memo),
          Text(createDate),
        ],
        // decoration: BoxDecoration(
        //   image: DecorationImage(
        //     image: CachedNetworkImageProvider(imgUrl),
        //     fit: BoxFit.cover,
        //   ),
        // ),
      ),
    );
  }
}
