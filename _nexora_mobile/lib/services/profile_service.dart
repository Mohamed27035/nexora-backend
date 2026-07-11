import 'dart:io';

import 'package:dio/dio.dart';

import 'api_service.dart';


class ProfileService {
  static Future<Response> getProfile() async {
    return ApiService.dio.get("users/profile/");
  }

  static Future<Response> updateProfile({
    String? nom,
    String? prenom,
    String? telephone,
    String? bio,
    String? password,
  }) async {
    final data = <String, dynamic>{};

    if (nom != null) data["nom"] = nom.trim();
    if (prenom != null) data["prenom"] = prenom.trim();
    if (telephone != null) data["telephone"] = telephone.trim();
    if (bio != null) data["bio"] = bio.trim();
    if (password != null && password.trim().isNotEmpty) {
      data["password"] = password.trim();
    }

    return ApiService.dio.put(
      "users/profile/update/",
      data: data,
    );
  }

  static Future<Response> uploadAvatar(File image) async {
    final fileName = image.path.split("/").last;

    final formData = FormData.fromMap({
      "avatar": await MultipartFile.fromFile(
        image.path,
        filename: fileName,
      ),
    });

    return ApiService.dio.put(
      "users/profile/update/",
      data: formData,
    );
  }
}
