import 'dart:convert';

import 'package:flutter/services.dart';


class Studentapi{
  static Future<Map<String, dynamic>> fetchClassRoster() async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));
    final String response = await rootBundle.loadString('assets/mock.json');
    // Parse the fake JSON
    return jsonDecode(response);
  }
}

