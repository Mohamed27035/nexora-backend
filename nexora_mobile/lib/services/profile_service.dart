import 'dart:io';

import 'package:dio/dio.dart';

import 'api_service.dart';


class ProfileService {

  // ==========================
  // GET PROFILE
  // ==========================
  static Future<Response>
      getProfile() async {

    return await ApiService.dio.get(

      "users/profile/",
    );
  }

  // ==========================
  // UPDATE PROFILE
  // ==========================
  static Future<Response>
      updateProfile({

    required String nom,

    required String prenom,

    required String telephone,

    required String bio,

  }) async {

    return await ApiService.dio.put(

      "users/profile/update/",

      data: {

        "nom": nom,

        "prenom": prenom,

        "telephone": telephone,

        "bio": bio,
      },
    );
  }

  // ==========================
  // UPLOAD AVATAR
  // ==========================
  static Future<Response>
      uploadAvatar(

    File image,
  ) async {

    String fileName =
        image.path
            .split("/")
            .last;

    FormData formData =
        FormData.fromMap({

      "avatar":
          await MultipartFile
              .fromFile(

        image.path,

        filename: fileName,
      ),
    });

    return await ApiService.dio.put(

      "users/profile/update/",

      data: formData,
    );
  }
}
