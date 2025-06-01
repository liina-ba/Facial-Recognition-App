import 'package:app_lina/common/utils/extensions/size_extension.dart';
import 'package:app_lina/constants/theme.dart';
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final GlobalKey formFieldKey;
  final String validatorText;

  const CustomTextField({
    Key? key,
    required this.formFieldKey,
    required this.controller,
    required this.hintText,
    required this.validatorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.055.sw, vertical: 0.02.sh),
      child: TextFormField(
          key: formFieldKey,
          controller: controller,
          cursorColor: primaryBlack.withOpacity(0.8),
          style: const TextStyle(
            color: primaryBlack,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
          decoration: InputDecoration(
            hintText: hintText,

            enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: accentColor),
      borderRadius: BorderRadius.circular(12),
    ),

          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return "this field cannot be empty";
            } else {
              return null;
            }
          }),
    );
  }
}
