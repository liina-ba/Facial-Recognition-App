import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_lina/constants/theme.dart';
import 'package:app_lina/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:app_lina/common/utils/custom_snackbar.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:app_lina/common/views/camera_viewpic.dart';
import 'package:app_lina/common/utils/extract_face_feature.dart';

class UpdateProfileView extends StatefulWidget {
  final UserModel user;
  const UpdateProfileView({super.key, required this.user});

  @override
  State<UpdateProfileView> createState() => _UpdateProfileViewState();
}

class _UpdateProfileViewState extends State<UpdateProfileView> {
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

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name ?? "";
    _emailController.text = widget.user.email ?? "";
    _passwordController.text = widget.user.password ?? "";
    _image = widget.user.image;
    _faceFeatures = widget.user.faceFeatures;
  }

  Future<void> _captureNewPhoto() async {
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
          final extracted = await extractFaceFeatures(inputImage, _faceDetector);
          setState(() => _faceFeatures = extracted);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    ));
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (_image == null || _faceFeatures == null) {
        CustomSnackBar.errorSnackBar("Veuillez capturer ou conserver une photo de visage.");
        return;
      }

      final updatedUser = UserModel(
        id: widget.user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        image: _image,
        faceFeatures: _faceFeatures,
        registeredOn: widget.user.registeredOn,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: accentColor)),
      );

      await FirebaseFirestore.instance.collection("users").doc(widget.user.id).set(updatedUser.toJson());
      if (mounted) Navigator.of(context).pop();

      CustomSnackBar.successSnackBar("informations successfully updated");
      Navigator.of(context).pop(updatedUser); // return updated user to HomeView
    }
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
              backgroundImage: _image != null ? MemoryImage(base64Decode(_image!)) : null,
              child: _image == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              onTap: _captureNewPhoto,
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
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            ),
            validator: (value) => value == null || value.isEmpty ? 'please enter $title' : null,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Profile"),
        backgroundColor: accentColor,
      ),
      backgroundColor: Colors.white,
      body: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _avatarWithCamera(),
                  const SizedBox(height: 20),
                  _entryField("Username", _nameController),
                  _entryField("Email", _emailController),
                  _entryField("Password", _passwordController, isPassword: true),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                    child: const Text("Save"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
