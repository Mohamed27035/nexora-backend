import 'package:flutter/material.dart';

import '../services/otp_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen
    extends StatefulWidget {

  const WelcomeScreen({
    super.key
  });

  @override
  State<WelcomeScreen>
      createState() =>
          _WelcomeScreenState();
}


class _WelcomeScreenState
    extends State<WelcomeScreen> {

  // ==========================
  // CONTROLLER
  // ==========================
  final emailController =
      TextEditingController();

  bool loading = false;

  // ==========================
  // SEND OTP
  // ==========================
  Future<void> sendOtp() async {

    if (emailController.text
        .trim()
        .isEmpty) {

      ScaffoldMessenger.of(
              context)
          .showSnackBar(

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

      await OtpService.sendOtp(

        email:
            emailController.text
                .trim(),
      );
    final prefs =
    await SharedPreferences
        .getInstance();

await prefs.setBool(

  "has_seen_welcome",

  true,
);
      if (mounted) {

        Navigator.pushNamed(

          context,

          "/otp",

          arguments:
              emailController.text
                  .trim(),
        );
      }

    } catch (_) {

  if (!mounted) return;

  ScaffoldMessenger.of(context)
      .showSnackBar(

    const SnackBar(
      content: Text(
        "Impossible d'envoyer le code OTP",
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

    return Scaffold(

      backgroundColor:
          Colors.white,

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
              // LOGO
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

                  Icons.account_balance_wallet,

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

                "Nexora",

                style: TextStyle(

                  fontSize: 38,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                  height: 10),

              const Text(

                "Enter your email to continue",

                style: TextStyle(

                  color:
                      Colors.grey,

                  fontSize: 18,
                ),
              ),

              const SizedBox(
                  height: 45),

              // ==========================
              // EMAIL FIELD
              // ==========================
              TextField(

                controller:
                    emailController,

                decoration:
                    InputDecoration(

                  hintText:
                      "Email address",

                  filled: true,

                  fillColor:
                      Colors.grey
                          .shade100,

                  prefixIcon:
                      const Icon(
                    Icons.email_outlined,
                  ),

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
              // CONTINUE BUTTON
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
                          : sendOtp,

                  child:
                      loading

                          ? const CircularProgressIndicator(
                              color:
                                  Colors.white,
                            )

                          : const Text(

                              "Continue",

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
                  height: 35),

              // ==========================
              // DIVIDER
              // ==========================
              Row(

                children: [

                  Expanded(

                    child: Divider(

                      color:
                          Colors.grey
                              .shade300,
                    ),
                  ),

                  const Padding(

                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 15,
                    ),

                    child: Text(

                      "or continue with",

                      style: TextStyle(

                        color:
                            Colors.grey,
                      ),
                    ),
                  ),

                  Expanded(

                    child: Divider(

                      color:
                          Colors.grey
                              .shade300,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                  height: 35),

              // ==========================
              // SSO BUTTON
              // ==========================
              SizedBox(

                width:
                    double.infinity,

                height: 60,

                child:
                    OutlinedButton(

                  style:
                      OutlinedButton
                          .styleFrom(

                    shape:
                        RoundedRectangleBorder(

                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),

                  onPressed: () {

                    ScaffoldMessenger.of(
                            context)
                        .showSnackBar(

                      const SnackBar(

                        content: Text(
                          "SSO Coming Soon",
                        ),
                      ),
                    );
                  },

                  child: const Row(

                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                    children: [

                      Icon(
                        Icons.business,
                      ),

                      SizedBox(
                          width: 12),

                      Text(

                        "Continue with SSO",

                        style:
                            TextStyle(

                          fontSize:
                              18,

                          color:
                              Colors.black,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ==========================
              // FOOTER
              // ==========================
              const Text(

                "Secure SSL 256-bit Connection",

                style: TextStyle(

                  color:
                      Colors.grey,
                ),
              ),

              const SizedBox(
                  height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
