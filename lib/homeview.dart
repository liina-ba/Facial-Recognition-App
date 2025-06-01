import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_face_api/face_api.dart' as regula;
import 'package:app_lina/model/user_model.dart';
import 'package:app_lina/constants/theme.dart';
import 'package:app_lina/common/utils/custom_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_lina/Widget/bezierContainer.dart';

import 'updateprofileview.dart';

class HomeView extends StatefulWidget {
  final UserModel user;

  const HomeView({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late UserModel currentUser;
  Uint8List? _testImage;
  double? _similarityScore;
  Color? _testResultColor;

  final AudioPlayer _audioPlayer = AudioPlayer();
  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
  }
  get _playFailedAudio => _audioPlayer
    ..stop()
    ..setReleaseMode(ReleaseMode.release)
    ..play(AssetSource("failed.mp3"));

  Future<void> _navigateToUpdateProfile() async {
    final updatedUser = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (context) => UpdateProfileView(user: currentUser),
      ),
    );

    if (updatedUser != null) {
      setState(() {
        currentUser = updatedUser;
      });
    }
  }

  Future<void> _startFaceTest({required bool fromCamera}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile == null) return;

    final capturedImageBytes = await pickedFile.readAsBytes();

    final similarity = await _compareTwoFaces(
      sourceImageBytes: base64Decode(currentUser.image!),
      capturedImageBytes: capturedImageBytes,
    );

    setState(() {
      _testImage = capturedImageBytes;
      _similarityScore = similarity;
      _testResultColor = similarity > 90.0 ? Colors.green : Colors.red;
    });


    if (similarity > 90.0) {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      await _audioPlayer.play(AssetSource("success.mp3"));

      CustomSnackBar.successSnackBar("Face match ✅");
    } else {
      _playFailedAudio;
      CustomSnackBar.errorSnackBar("Face doesn't match❌");
    }

  }

  Future<double> _compareTwoFaces({
    required Uint8List sourceImageBytes,
    required Uint8List capturedImageBytes,
  }) async {
    final image1 = regula.MatchFacesImage()
      ..bitmap = base64Encode(sourceImageBytes)
      ..imageType = regula.ImageType.PRINTED;

    final image2 = regula.MatchFacesImage()
      ..bitmap = base64Encode(capturedImageBytes)
      ..imageType = regula.ImageType.LIVE;

    try {
        final request = regula.MatchFacesRequest();
        request.images = [image1, image2];
      
      final result = await regula.FaceSDK.matchFaces(jsonEncode(request));
      final response = regula.MatchFacesResponse.fromJson(json.decode(result));

      final str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
        jsonEncode(response!.results),
        0.75,
      );

      final split = regula.MatchFacesSimilarityThresholdSplit.fromJson(
        json.decode(str),
      );

      final similarity = split!.matchedFaces.isNotEmpty
          ? (split.matchedFaces.first!.similarity!.toDouble() * 100)
          : 0.0;

      return similarity;
    } catch (e) {
      debugPrint("Face comparison failed: $e");
      return 0.0;
    }
  }




  Widget _title() {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        text: 'Vision',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
        children: [
          TextSpan(
            text: 'ary',
            style: TextStyle(color: Colors.white, fontSize: 30),
          ),
        ],
      ),
    );
  }
Widget _updateprofil(BuildContext context) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _navigateToUpdateProfile,
      icon: const Icon(Icons.person, color: Colors.white), // User face icon

      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFB7D6EA),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 5,
        shadowColor: Color(0xFFB7D6EA).withAlpha(100),
      ),

      label: const Text(
        'Profil',
        style: TextStyle(fontSize: 15),
      ),
    ),
  );
}


  Widget _buildProfileSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage:
              currentUser.image != null ? MemoryImage(base64Decode(currentUser.image!)) : null,
          child: currentUser.image == null
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          'Welcome, ${currentUser.name ?? ''}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
       
        //const SizedBox(height: 15),
        // _updateprofil(context),


      ],
    );
  }

  Widget _buildFaceTestSection() {
    return Column(
      children: [
        const SizedBox(height: 10),
          const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "Facial recognition test ",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
        const SizedBox(height: 15),
       Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _startFaceTest(fromCamera: false),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white, // Icon background
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.image, color: Color(0xFF6A5C7A)),
        ),
        label: const Text(
          "Galerry",
          style: TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF6A5C7A),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _startFaceTest(fromCamera: true),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.camera_alt, color: Color(0xFF6A5C7A)),
        ),
        label: const Text(
          "Camera",
          style: TextStyle(color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    ),
  ],
),

        const SizedBox(height: 20),
        if (_testImage != null)
          Column(
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: _testResultColor ?? Colors.transparent, width: 4),
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: MemoryImage(_testImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_similarityScore != null)
                Text(
                  "Score of similarity : ${_similarityScore!.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: _testResultColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

 return Scaffold(
      backgroundColor: Colors.white,
    appBar: AppBar(
  backgroundColor: Color(0xFF4A3F55),
  elevation: 0,
  centerTitle: true,
  title: _title(),
  actions: [
    IconButton(
      icon: const Icon(Icons.person, color: Colors.black),
      onPressed: _navigateToUpdateProfile, // Your function to go to profile
    ),
  ],
),

      body: SizedBox(
        height: height,
        child: Stack(
          children: [
         
      Container(

        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(

        child: Column(
          children: [ 
              const SizedBox(height:30),
             _buildProfileSection(),
              const SizedBox(height: 20),
            _buildFaceTestSection(),
          ],
        ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}
