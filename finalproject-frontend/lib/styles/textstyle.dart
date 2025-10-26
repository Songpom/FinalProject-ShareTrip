import 'package:flutter/material.dart';
import 'AppColors.dart';

class KTextStyle {
  static const TextStyle input = TextStyle(fontSize: 16, color: Colors.black);
  static const TextStyle hint = TextStyle(fontSize: 14, color: AppColors.hintText);
  static const TextStyle button = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white);
  static const TextStyle link = TextStyle(fontSize: 14, color: AppColors.primary, decoration: TextDecoration.underline);
  
  // เพิ่มสไตล์หัวข้อที่เล็กและอยู่ซ้าย
  static const TextStyle label = TextStyle(fontSize: 14, color: Colors.black);
}
