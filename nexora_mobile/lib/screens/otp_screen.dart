import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/otp_service.dart';


class OtpScreen
    extends StatefulWidget {

  const OtpScreen({
    super.key
  });

  @override
  State<OtpScreen>
      createState() =>
          _OtpScreenState();
}


class _OtpScreenState
    extends State<OtpScreen> {

  // ==========================
  // CONTROLLER
  // ==========================
  final otpController =
      TextEditingController();

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
              context)
          .showSnackBar(

        const SnackBar(

          content: Text(
            "Enter OTP code",
          ),
        ),
      );

      return;
    }

    setState(() {

      loading = true;
    });

    try {

      await OtpService.verifyOtp(

        email: email,

        otp:
            otpController.text
                .trim(),
      );

      if (mounted) {

        Navigator.pushReplacementNamed(

          context,

          "/login",
        );
      }

    } catch (_) {

      if (!mounted) return;

      ScaffoldMessenger.of(
              context)
          .showSnackBar(

        const SnackBar(

          content: Text(
            "Invalid OTP",
          ),
        ),
      );
    }

    if (!mounted) return;

    setState(() {

      loading = false;
    });
  }

  @override
  Widget build(
    BuildContext context
  ) {

    // ==========================
    // GET EMAIL
    // ==========================
    final email =
        ModalRoute.of(context)!
            .settings
            .arguments as String;

    return Scaffold(

      backgroundColor:
          AppColors.background,

      body: SafeArea(

        child: Padding(

          padding:
              const EdgeInsets.all(
            25,
          ),

          child: Column(

            children: [

              const Spacer(),

              // ==========================
              // ICON
              // ==========================
              Container(

                width: 110,

                height: 110,

                decoration:
                    BoxDecoration(

                  color:
                      const Color(
                    0xFF2563EB,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                ),

                child: const Icon(

                  Icons.lock_outline,

                  color: Colors.white,

                  size: 50,
                ),
              ),

              const SizedBox(
                  height: 25),

              // ==========================
              // TITLE
              // ==========================
              const Text(

                "OTP Verification",

                style: TextStyle(

                  fontSize: 34,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                  height: 10),

              Text(

                "Code sent to\n$email",

                textAlign:
                    TextAlign.center,

                style: const TextStyle(

                  color:
                      Colors.grey,

                  fontSize: 18,
                ),
              ),

              const SizedBox(
                  height: 45),

              // ==========================
              // OTP FIELD
              // ==========================
              TextField(

                controller:
                    otpController,

                keyboardType:
                    TextInputType
                        .number,

                textAlign:
                    TextAlign.center,

                style: const TextStyle(

                  fontSize: 28,

                  letterSpacing: 10,
                ),

                decoration:
                    InputDecoration(

                  hintText:
                      "------",

                  filled: true,

                  fillColor:
                      Colors.grey
                          .shade100,

                  border:
                      OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(
                  height: 25),

              // ==========================
              // VERIFY BUTTON
              // ==========================
              SizedBox(

                width:
                    double.infinity,

                height: 60,

                child:
                    ElevatedButton(

                  style:
                      ElevatedButton
                          .styleFrom(

                    backgroundColor:
                        const Color(
                      0xFF2563EB,
                    ),

                    shape:
                        RoundedRectangleBorder(

                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),

                  onPressed:
                      loading
                          ? null
                          : () => verifyOtp(
                                email,
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
                                    20,

                                color:
                                    Colors.white,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                ),
              ),

              const SizedBox(
                  height: 20),

              // ==========================
              // RESEND
              // ==========================
              TextButton(

                onPressed: () async {

                  try {

                    await OtpService
                        .sendOtp(

                      email: email,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(
                            context)
                        .showSnackBar(

                      const SnackBar(

                        content: Text(
                          "OTP resent",
                        ),
                      ),
                    );

                  } catch (_) {
                  }
                },

                child: const Text(

                  "Resend OTP",

                  style: TextStyle(

                    fontSize: 16,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }
}
