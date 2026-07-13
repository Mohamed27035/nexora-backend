import 'dart:io';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../services/profile_service.dart';


class ProfileScreen
    extends StatefulWidget {

  const ProfileScreen({
    super.key
  });

  @override
  State<ProfileScreen>
      createState() =>
          _ProfileScreenState();
}


class _ProfileScreenState
    extends State<ProfileScreen> {

  // ==========================
  // CONTROLLERS
  // ==========================
  final nomController =
      TextEditingController();

  final prenomController =
      TextEditingController();

  final telephoneController =
      TextEditingController();

  final bioController =
      TextEditingController();

  // ==========================
  // STATES
  // ==========================
  bool loading = true;

  bool saving = false;

  String avatar = "";

  String email = "";

String role = "";

String lastLogin = "";

String lastIp = "";

  File? selectedImage;

  // ==========================
  // FETCH PROFILE
  // ==========================
  Future<void>
      fetchProfile() async {

    try {

      final response =
          await ProfileService
              .getProfile();

      final data =
          response.data;

      nomController.text =
          data["nom"] ?? "";

      prenomController.text =
          data["prenom"] ?? "";

      telephoneController.text =
          data["telephone"] ?? "";

      bioController.text =
          data["bio"] ?? "";

      avatar =
          data["avatar"] ?? "";

          email =
    data["email"] ?? "";

role =
    data["role"] ?? "";

lastLogin =
    data["last_login"]
        ?.toString() ??
    "";

lastIp =
    data["last_ip"] ?? "";

      setState(() {

        loading = false;
      });

    } catch (_) {

      setState(() {

        loading = false;
      });
    }
  }

  // ==========================
  // PICK IMAGE
  // ==========================
  Future<void>
      pickImage() async {

    final picker =
        ImagePicker();

    final picked =
        await picker.pickImage(

      source:
          ImageSource.gallery,
    );

    if (picked != null) {

      setState(() {

        selectedImage =
            File(picked.path);
      });
    }
  }

  // ==========================
  // SAVE PROFILE
  // ==========================
  Future<void>
      saveProfile() async {

    setState(() {

      saving = true;
    });

    try {

      // UPDATE INFO
      await ProfileService
          .updateProfile(

        nom:
            nomController.text,

        prenom:
            prenomController.text,

        telephone:
            telephoneController
                .text,

        bio:
            bioController.text,
      );

      // UPLOAD AVATAR
      if (selectedImage !=
          null) {

        await ProfileService
            .uploadAvatar(

          selectedImage!,
        );
      }

      if (mounted) {

        ScaffoldMessenger.of(
                context)
            .showSnackBar(

          const SnackBar(

            content: Text(
              "Profile updated",
            ),
          ),
        );
      }

      fetchProfile();

    } catch (_) {
    }

    setState(() {

      saving = false;
    });
  }

  @override
  void initState() {

    super.initState();

    fetchProfile();
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    telephoneController.dispose();
    bioController.dispose();
    super.dispose();
  }

  // ==========================
  // FIELD
  // ==========================
  Widget buildField({

    required String label,

    required TextEditingController
        controller,

    int maxLines = 1,

  }) {

    return Padding(

      padding:
          const EdgeInsets.only(
        bottom: 20,
      ),

      child: TextField(

        controller:
            controller,

        maxLines: maxLines,

        style:
            const TextStyle(

          color:
              AppColors.text,
        ),

        decoration:
            InputDecoration(

          labelText: label,

          labelStyle:
              const TextStyle(

            color:
                AppColors.muted,
          ),

          filled: true,

          fillColor:
              AppColors.surface,

          border:
              OutlineInputBorder(

            borderRadius:
                BorderRadius.circular(
              18,
            ),

            borderSide:
                BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context
  ) {

    return Scaffold(

      appBar: AppBar(

        backgroundColor:
            const Color(
          0xFFFBF7FF,
        ),

        title: const Text(
          "Profile",
        ),
      ),

      body:
          loading

              ? const Center(

                  child:
                      CircularProgressIndicator(),
                )

              : SingleChildScrollView(

                  padding:
                      const EdgeInsets.all(
                    20,
                  ),

                  child: Column(

                    children: [

                      // ==========================
                      // AVATAR
                      // ==========================
                      GestureDetector(

                        onTap: pickImage,

                        child: CircleAvatar(

                          radius: 60,

                          backgroundColor:
                              AppColors.panel,

                          backgroundImage:

                              selectedImage !=
                                      null

                                  ? FileImage(
                                      selectedImage!,
                                    )

                                  : avatar
                                          .isNotEmpty

                                      ? NetworkImage(
                                          avatar,
                                        )

                                      : null,

                          child:

                              selectedImage ==
                                          null &&
                                      avatar
                                          .isEmpty

                                  ? const Icon(

                                      Icons.person,

                                      size: 60,

                                      color:
                                          AppColors.text,
                                    )

                                  : null,
                        ),
                      ),

                      const SizedBox(
                          height: 15),

                      const Text(

                        "Tap avatar to change photo",

                        style: TextStyle(

                          color:
                              AppColors.muted,
                        ),
                      ),

                      const SizedBox(
                          height: 35),

                          Container(

  width: double.infinity,

  padding:
      const EdgeInsets.all(
    18,
  ),

  decoration: BoxDecoration(

    color: AppColors.surface,

    borderRadius:
        BorderRadius.circular(
      18,
    ),
  ),

  child: Column(

    crossAxisAlignment:
        CrossAxisAlignment.start,

    children: [

      Text(

        email,

        style: const TextStyle(

          color: AppColors.text,

          fontSize: 16,
        ),
      ),

      const SizedBox(
          height: 10),

      Text(

        "Role: $role",

        style: const TextStyle(

          color: AppColors.muted,
        ),
      ),

      const SizedBox(
          height: 10),

      Text(

        "Last Login: $lastLogin",

        style: const TextStyle(

          color: AppColors.muted,
        ),
      ),

      const SizedBox(
          height: 10),

      Text(

        "Last IP: $lastIp",

        style: const TextStyle(

          color: AppColors.muted,
        ),
      ),
    ],
  ),
),

const SizedBox(
    height: 30),

                      // ==========================
                      // FIELDS
                      // ==========================
                      buildField(

                        label: "Nom",

                        controller:
                            nomController,
                      ),

                      buildField(

                        label: "Prenom",

                        controller:
                            prenomController,
                      ),

                      buildField(

                        label: "Telephone",

                        controller:
                            telephoneController,
                      ),

                      buildField(

                        label: "Bio",

                        controller:
                            bioController,

                        maxLines: 4,
                      ),

                      const SizedBox(
                          height: 20),

                      // ==========================
                      // SAVE BUTTON
                      // ==========================
                      SizedBox(

                        width:
                            double.infinity,

                        height: 55,

                        child:
                            ElevatedButton(

                          onPressed:
                              saving
                                  ? null
                                  : saveProfile,

                          child:

                              saving

                                  ? const CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                    )

                                  : const Text(

                                      "Save Profile",
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
