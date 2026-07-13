import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class ResetPasswordOtpScreen
    extends StatefulWidget {

  const ResetPasswordOtpScreen({
    super.key,
  });

  @override
  State<ResetPasswordOtpScreen>
      createState() =>
          _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState
    extends State<ResetPasswordOtpScreen> {

  // ==========================
  // CONTROLLERS
  // ==========================
  final otpController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final confirmPasswordController =
      TextEditingController();

  // ==========================
  // STATE
  // ==========================
  bool loading = false;

  // ==========================
  // VERIFY OTP
  // ==========================
  Future<void> verifyOtp(
    String email,
  ) async {

    if (otpController.text
        .trim()
        .isEmpty) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "Enter OTP",
          ),
        ),
      );

      return;
    }

    if (passwordController.text
            .trim()
            .isEmpty ||
        confirmPasswordController
            .text
            .trim()
            .isEmpty) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "Enter password",
          ),
        ),
      );

      return;
    }

    if (passwordController.text !=
        confirmPasswordController
            .text) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "Passwords do not match",
          ),
        ),
      );

      return;
    }

    setState(() {

      loading = true;
    });

    try {

      await AuthService.verifyOtp(

        email: email,

        otp:
            otpController.text
                .trim(),

        password:
            passwordController
                .text
                .trim(),
      );

      if (mounted) {

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(

          const SnackBar(

            content: Text(
              "Password updated successfully",
            ),
          ),
        );

        Navigator.pushNamedAndRemoveUntil(

          context,

          "/login",

          (route) => false,
        );
      }

    } catch (_) {

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "OTP verification failed",
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    final email = ModalRoute.of(
      context,
    )!.settings.arguments as String;

    return Scaffold(

      backgroundColor:
          AppColors.background,

      appBar: AppBar(

        title: const Text(
          "Verify OTP",
        ),
      ),

      body: SingleChildScrollView(

        padding:
            const EdgeInsets.all(
          24,
        ),

        child: Column(

          children: [

            const SizedBox(
                height: 40),

            const Icon(

              Icons.security,

              size: 90,

              color: AppColors.text,
            ),

            const SizedBox(
                height: 30),

            const Text(

              "OTP Verification",

              style: TextStyle(

                color:
                    AppColors.text,

                fontSize: 30,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 15),

            Text(

              email,

              style: const TextStyle(

                color:
                    AppColors.muted,

                fontSize: 16,
              ),
            ),

            const SizedBox(
                height: 40),

            // ==========================
            // OTP
            // ==========================
            TextField(

              controller:
                  otpController,

              keyboardType:
                  TextInputType.number,

              style:
                  const TextStyle(
                color: AppColors.text,
              ),

              decoration:
                  InputDecoration(

                hintText:
                    "OTP Code",

                hintStyle:
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
                    14,
                  ),

                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),

            const SizedBox(
                height: 20),

            // ==========================
            // PASSWORD
            // ==========================
            TextField(

              controller:
                  passwordController,

              obscureText: true,

              style:
                  const TextStyle(
                color: AppColors.text,
              ),

              decoration:
                  InputDecoration(

                hintText:
                    "New Password",

                hintStyle:
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
                    14,
                  ),

                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),

            const SizedBox(
                height: 20),

            // ==========================
            // CONFIRM PASSWORD
            // ==========================
            TextField(

              controller:
                  confirmPasswordController,

              obscureText: true,

              style:
                  const TextStyle(
                color: AppColors.text,
              ),

              decoration:
                  InputDecoration(

                hintText:
                    "Confirm Password",

                hintStyle:
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
                    14,
                  ),

                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),

            const SizedBox(
                height: 35),

            // ==========================
            // BUTTON
            // ==========================
            SizedBox(

              width:
                  double.infinity,

              height: 55,

              child:
                  ElevatedButton(

                onPressed:
                    loading
                        ? null
                        : () => verifyOtp(
                              email,
                            ),

                style:
                    ElevatedButton
                        .styleFrom(

                  backgroundColor:
                      const Color(
                    0xFF3B82F6,
                  ),

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),

                child:
                    loading

                        ? const CircularProgressIndicator(
                            color:
                                Colors.white,
                          )

                        : const Text(

                            "Verify OTP",

                            style:
                                TextStyle(
                              fontSize:
                                  18,
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
