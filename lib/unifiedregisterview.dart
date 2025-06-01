import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_lina/Widget/bezierContainer.dart';
import 'package:app_lina/common/utils/custom_snackbar.dart';
import 'package:app_lina/common/utils/extract_face_feature.dart';
import 'package:app_lina/common/views/camera_viewpic.dart';
import 'package:app_lina/constants/theme.dart';
import 'package:app_lina/login_view.dart';
import 'package:app_lina/main.dart';
import 'package:app_lina/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:uuid/uuid.dart';

class UnifiedRegisterView extends StatefulWidget {
  const UnifiedRegisterView({Key? key}) : super(key: key);

  @override
  State<UnifiedRegisterView> createState() => _UnifiedRegisterViewState();
}

class _UnifiedRegisterViewState extends State<UnifiedRegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _image;
  FaceFeatures? _faceFeatures;

  Future<void> _startCapture() async {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CameraViewPic(
        onImage: (image) {
          setState(() {
            _image = base64Encode(image);
          });
        },
        onInputImage: (inputImage) async {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator(color: accentColor)),
          );

          _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);

          // Always dismiss the loading dialog first
          if (mounted) Navigator.of(context).pop();

          // Check if face features were detected
          if (_faceFeatures == null) {
            CustomSnackBar.errorSnackBar("No face detected. Please try again with a clear face image.");
            return;
          }

          setState(() {});
        },
      ),
    ));
  }
  void _registerUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_image == null || _faceFeatures == null) {
        CustomSnackBar.errorSnackBar("Please capture your face first.");
        return;
      }

      FocusScope.of(context).unfocus();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: accentColor)),
      );

      try {
        // 🔍 Check if a user with the same email already exists
        final existingUser = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: _emailController.text.trim())
            .limit(1)
            .get();

        if (existingUser.docs.isNotEmpty) {
          Navigator.of(context).pop();
          CustomSnackBar.errorSnackBar("Registration Failed: User already exists.");
          return;
        }

        String userId = const Uuid().v1();
        UserModel user = UserModel(
          id: userId,
          name: _nameController.text.trim().toUpperCase(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          image: _image!,
          faceFeatures: _faceFeatures!,
          registeredOn: DateTime.now().millisecondsSinceEpoch,
        );

        await FirebaseFirestore.instance.collection("users").doc(userId).set(user.toJson());

        Navigator.of(context).pop();
        CustomSnackBar.successSnackBar("Registration Success");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Home()),
              (route) => false,
        );
      } catch (e) {
        Navigator.of(context).pop();
        CustomSnackBar.errorSnackBar("Unexpected error: ${e.toString()}");
      }
    }
  }

  Widget _backButton() {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
              child: const Icon(Icons.keyboard_arrow_left, color: Colors.black),
            ),
            const Text('Back',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
          ],
        ),
      ),
    );
  }

  Widget _title() {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        text: 'Vision',
        style: TextStyle(fontSize: 35, fontWeight: FontWeight.w700, color: Color(0xFF2D2533)),
        children: [
          TextSpan(text: 'ary', style: TextStyle(color: Colors.black, fontSize: 35)),
        ],
      ),
    );
  }


Widget _avatarWithCamera() {
  return SizedBox(
    width: 120,
    height: 120,
    child: Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage:
                _image != null ? MemoryImage(base64Decode(_image!)) : null,
            child: _image == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: _startCapture,
            child: Container(
              decoration: const BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}



  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              hintText: title,
              border: InputBorder.none,
              fillColor: const Color(0xfff3f3f4),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15), //

            ),
            validator: (value) => value == null || value.isEmpty ? 'Please enter $title' : null,
          )
        ],
      ),
    );
  }

  Widget _loginAccountLabel() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginView())),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(15),
        alignment: Alignment.bottomCenter,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Already have an account ?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(width: 10),
            Text("Login", style: TextStyle(color: Color(0xFF4A3F55), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,

      body: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned(
              top: -MediaQuery.of(context).size.height * .15,
              right: -MediaQuery.of(context).size.width * .4,
              child: const BezierContainer(),
            ),
            Positioned(top: 40, left: 0, child: _backButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: height * 0.13),
                    _title(),
                    const SizedBox(height: 20),
                    _avatarWithCamera(),
                    const SizedBox(height: 15),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _entryField("Username", _nameController),
                          _entryField("Email", _emailController),
                          _entryField("Password", _passwordController, isPassword: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _registerUser,
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF6A5C7A),Color(0xFF4A3F55)]
                            )
                        ),
                        child: const Text('Register now', style: TextStyle(fontSize: 20, color: Colors.white)),
                      ),
                    ),
                    SizedBox(height: height * 0.02),
                    _loginAccountLabel(),
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

