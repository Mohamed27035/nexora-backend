import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen
    extends StatefulWidget {

  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen>
      createState() =>
          _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {

  // ==========================
  // CONTROLLER
  // ==========================
  final emailController =
      TextEditingController();

  // ==========================
  // STATE
  // ==========================
  bool loading = false;

  // ==========================
  // SEND OTP
  // ==========================
  Future<void> sendOtp() async {

    if (emailController.text
        .trim()
        .isEmpty) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "Enter your email",
          ),
        ),
      );

      return;
    }

    setState(() {

      loading = true;
    });

    try {

      await AuthService.sendOtp(

        email:
            emailController.text
                .trim(),
      );

      if (mounted) {

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(

          const SnackBar(

            content: Text(
              "OTP sent successfully",
            ),
          ),
        );

        Navigator.pushNamed(

          context,

          "/reset-password-otp",

          arguments:
              emailController.text
                  .trim(),
        );
      }

    } catch (_) {

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "Failed to send OTP",
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
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      backgroundColor:
          AppColors.background,

      appBar: AppBar(

        title: const Text(
          "Forgot Password",
        ),
      ),

      body: Center(

        child: Padding(

          padding:
              const EdgeInsets.all(
            24,
          ),

          child: Column(

            mainAxisAlignment:
                MainAxisAlignment
                    .center,

            children: [

              const Icon(

                Icons.lock_reset,

                size: 90,

                color: AppColors.text,
              ),

              const SizedBox(
                  height: 30),

              const Text(

                "Reset Password",

                style: TextStyle(

                  color:
                      AppColors.text,

                  fontSize: 32,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                  height: 15),

              const Text(

                "Enter your email to receive OTP",

                textAlign:
                    TextAlign.center,

                style: TextStyle(

                  color:
                      AppColors.muted,

                  fontSize: 16,
                ),
              ),

              const SizedBox(
                  height: 40),

              // ==========================
              // EMAIL
              // ==========================
              TextField(

                controller:
                    emailController,

                style:
                    const TextStyle(
                  color: AppColors.text,
                ),

                decoration:
                    InputDecoration(

                  hintText:
                      "Email",

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
                  height: 30),

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
                          : sendOtp,

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

                              "Send OTP",

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
      ),
    );
  }
}
