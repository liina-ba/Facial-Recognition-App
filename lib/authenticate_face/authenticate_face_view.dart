import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_lina/authenticate_face/scanning_animation/animated_view.dart';
import 'package:app_lina/common/utils/custom_snackbar.dart';
import 'package:app_lina/common/utils/extensions/size_extension.dart';
import 'package:app_lina/common/utils/extract_face_feature.dart';
import 'package:app_lina/common/views/camera_viewpic.dart';
import 'package:app_lina/common/views/custom_button.dart';
import 'package:app_lina/constants/theme.dart';
import 'package:app_lina/homeview.dart';
import 'package:app_lina/model/user_model.dart';

import 'package:flutter_face_api/face_api.dart' as regula;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AuthenticateFaceView extends StatefulWidget {
  const AuthenticateFaceView({Key? key}) : super(key: key);

  @override
  State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
}

class _AuthenticateFaceViewState extends State<AuthenticateFaceView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  FaceFeatures? _faceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();


  bool _canAuthenticate = false;

  List<dynamic> users = [];

  UserModel? loggingUser;

  bool isMatching = false;


  @override
  void dispose() {
    _faceDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  get _playScanningAudio => _audioPlayer
    ..setReleaseMode(ReleaseMode.loop)
    ..play(AssetSource("scan_beep.wav"));

  get _playFailedAudio => _audioPlayer
    ..stop()
    ..setReleaseMode(ReleaseMode.release)
    ..play(AssetSource("failed.mp3"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: const Text("Authenticate Face"),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 0.82.sh,
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(0.05.sw, 0.025.sh, 0.05.sw, 0),
                      decoration: BoxDecoration(
                        color: overlayContainerClr,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(0.03.sh),
                          topRight: Radius.circular(0.03.sh),
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CameraViewPic(
                                onImage: (image) {
                                  image2.bitmap = base64Encode(image);
                                  image2.imageType = regula.ImageType.PRINTED;
                                  setState(() => _canAuthenticate = true);
                                },
                                onInputImage: (inputImage) async {
                                  setState(() => isMatching = true);
                                  try {
                                    _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);

                                    // Check if face features were detected
                                    if (_faceFeatures == null) {
                                      // No face detected
                                      setState(() => isMatching = false);
                                      _playFailedAudio;
                                      CustomSnackBar.errorSnackBar("No face detected. Please try again with a clear face image.");
                                      return;
                                    }
                                  } catch (e) {
                                    // Handle any exceptions
                                    log("Error detecting face: $e");
                                    setState(() => isMatching = false);
                                    _playFailedAudio;
                                    CustomSnackBar.errorSnackBar("Error processing image. Please try again.");
                                    return;
                                  }

                                  setState(() => isMatching = false);
                                },
                              ),
                              if (isMatching)
                                Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 0.064.sh),
                                    child: const AnimatedView(),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (_canAuthenticate)
                            CustomButton(
                              text: "Authenticate",
                              onTap: () {
                                setState(() => isMatching = true);
                                //_playScanningAudio;
                                _fetchUsersAndMatchFace();
                              },
                            ),
                          SizedBox(height: 0.038.sh),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }


  _fetchUsersAndMatchFace() {
    // Check if face features are available
    if (_faceFeatures == null) {
      setState(() => isMatching = false);
      _playFailedAudio;
      CustomSnackBar.errorSnackBar("No face detected. Please try again with a clear face image.");
      return;
    }

    FirebaseFirestore.instance.collection("users").get().catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      _playFailedAudio;
      CustomSnackBar.errorSnackBar("Something went wrong. Please try again.");
    }).then((snap) async {
      if (snap.docs.isNotEmpty) {
        users.clear();
        for (var doc in snap.docs)
        {
          UserModel user = UserModel.fromJson(doc.data());
          double similarity = compareFaces(_faceFeatures!, user.faceFeatures!);
          if (similarity >= 0.8 && similarity <= 1.5) {
            users.add([user, similarity]);
          }
        }

        users.sort((a, b) => (((a.last as double) - 1).abs())
            .compareTo(((b.last as double) - 1).abs()));

        await _matchFaces();
      } else {
        _showFailureDialog(
          title: "No Users Registered",
          description: "Please register first.",
        );
      }
    });
  }

  _matchFaces() async {
    bool faceMatched = false;

    for (List user in users) {
      image1.bitmap = (user.first as UserModel).image;
      image1.imageType = regula.ImageType.PRINTED;


      var request = regula.MatchFacesRequest();

      request.images = [image1, image2];
      var result = await regula.FaceSDK.matchFaces(jsonEncode(request));
      var response = regula.MatchFacesResponse.fromJson(json.decode(result));
      var str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
          jsonEncode(response?.results), 0.75);

      var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(
          json.decode(str));

      double similarity = split!.matchedFaces.isNotEmpty
          ? (split.matchedFaces.first!.similarity! * 100)
          : 0.0;

      if (similarity > 90.0) {
        faceMatched = true;
        loggingUser = user.first;

        _audioPlayer
          ..stop()
          ..setReleaseMode(ReleaseMode.release)
          ..play(AssetSource("success.mp3"));

        setState(() {

          isMatching = false;
        });

// Delay navigation
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomeView(user: loggingUser!),
              ),
            );
          }
        });

        break; // ✅ OUTSIDE Future.delayed
      }
    }

    if (!faceMatched) {
      _showFailureDialog(
        title: "Authentication Failed",
        description: "Face doesn't match any user.",
      );
    }
  }

  double compareFaces(FaceFeatures face1, FaceFeatures face2) {
    double distEar1 = euclideanDistance(face1.rightEar!, face1.leftEar!);
    double distEar2 = euclideanDistance(face2.rightEar!, face2.leftEar!);

    double ratioEar = distEar1 / distEar2;

    double distEye1 = euclideanDistance(face1.rightEye!, face1.leftEye!);
    double distEye2 = euclideanDistance(face2.rightEye!, face2.leftEye!);

    double ratioEye = distEye1 / distEye2;

    double distCheek1 = euclideanDistance(face1.rightCheek!, face1.leftCheek!);
    double distCheek2 = euclideanDistance(face2.rightCheek!, face2.leftCheek!);

    double ratioCheek = distCheek1 / distCheek2;

    double distMouth1 = euclideanDistance(face1.rightMouth!, face1.leftMouth!);
    double distMouth2 = euclideanDistance(face2.rightMouth!, face2.leftMouth!);

    double ratioMouth = distMouth1 / distMouth2;

    double distNoseToMouth1 =
    euclideanDistance(face1.noseBase!, face1.bottomMouth!);
    double distNoseToMouth2 =
    euclideanDistance(face2.noseBase!, face2.bottomMouth!);

    double ratioNoseToMouth = distNoseToMouth1 / distNoseToMouth2;

    return (ratioEye + ratioEar + ratioCheek + ratioMouth + ratioNoseToMouth) / 5;
  }

  double euclideanDistance(Points p1, Points p2) {
    return math.sqrt(math.pow((p1.x! - p2.x!), 2) +
        math.pow((p1.y! - p2.y!), 2));
  }

  _showFailureDialog({required String title, required String description}) {
    _playFailedAudio;
    setState(() => isMatching = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Ok", style: TextStyle(color: accentColor)),
          )
        ],
      ),
    );
  }
}

