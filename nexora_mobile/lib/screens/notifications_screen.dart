import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/notification_service.dart';


class NotificationsScreen
    extends StatefulWidget {

  const NotificationsScreen({
    super.key
  });

  @override
  State<NotificationsScreen>
      createState() =>
          _NotificationsScreenState();
}


class _NotificationsScreenState
    extends State<NotificationsScreen> {

  // ==========================
  // STATES
  // ==========================
  List notifications = [];

  bool loading = true;
  String? errorMessage;

  // ==========================
  // FETCH
  // ==========================
  Future<void>
      fetchNotifications() async {

    try {

      final response =
          await NotificationService
              .getNotifications();
      final data = response.data;

      setState(() {

        notifications = _asList(data);

        loading = false;
        errorMessage = null;
      });

    } catch (_) {

      setState(() {

        loading = false;
        errorMessage = "Impossible de charger les notifications";
      });
    }
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data["results"] is List) return data["results"];
    if (data is Map && data["notifications"] is List) {
      return data["notifications"];
    }
    if (data is Map && data["data"] is List) return data["data"];
    return [];
  }

  // ==========================
  // READ
  // ==========================
  Future<void>
      markAsRead(int id) async {

    try {

      await NotificationService
          .markAsRead(id);

      fetchNotifications();

    } catch (_) {
    }
  }

  // ==========================
  // DELETE
  // ==========================
  Future<void>
      deleteNotif(int id) async {

    try {

      await NotificationService
          .deleteNotification(id);

      fetchNotifications();

    } catch (_) {
    }
  }

  @override
  void initState() {

    super.initState();

    fetchNotifications();
  }

  @override
  Widget build(
    BuildContext context
  ) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          "Notifications",
        ),
      ),

      body:
          loading

              ? const Center(

                  child:
                      CircularProgressIndicator(),
                )

              : errorMessage != null

                  ? Center(

                      child: Padding(

                        padding: const EdgeInsets.all(24),

                        child: Text(

                          errorMessage!,

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    )

                  : notifications.isEmpty

                  ? const Center(

                      child: Text(

                        "No notifications",

                        style: TextStyle(
                              color:
                                  AppColors.text,
                        ),
                      ),
                    )

                  : ListView.builder(

                      padding:
                          const EdgeInsets.all(
                        20,
                      ),

                      itemCount:
                          notifications.length,

                      itemBuilder:
                          (context, index) {

                        final n =
                            notifications[
                                index];

                        return Container(

                          margin:
                              const EdgeInsets.only(
                            bottom: 15,
                          ),

                          padding:
                              const EdgeInsets.all(
                            18,
                          ),

                          decoration:
                              BoxDecoration(

                            color: n["is_read"] == true
                                ? AppColors.surface
                                : AppColors.primary.withValues(alpha: 0.12),

                            borderRadius:
                                BorderRadius.circular(
                              18,
                            ),

                            border: Border.all(
                              color: AppColors.surfaceSoft,
                            ),
                          ),

                          child: Column(

                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              // ==========================
                              // TITLE
                              // ==========================
                              Text(

                                n["title"]?.toString() ?? "Notification",

                                style:
                                    const TextStyle(

                                  color:
                                      AppColors.text,

                                  fontSize:
                                      18,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                  height: 10),

                              // ==========================
                              // MESSAGE
                              // ==========================
                              Text(

                                n["message"]?.toString() ?? "",

                                style:
                                    const TextStyle(

                                  color:
                                      AppColors.muted,
                                ),
                              ),

                              const SizedBox(
                                  height: 15),

                              // ==========================
                              // ACTIONS
                              // ==========================
                              Row(

                                children: [

                                  if (!n[
                                      "is_read"])

                                    ElevatedButton(

                                      onPressed:
                                          () {

                                        markAsRead(
                                          n["id"],
                                        );
                                      },

                                      child:
                                          const Text(
                                        "Read",
                                      ),
                                    ),

                                  const SizedBox(
                                      width: 10),

                                  ElevatedButton(

                                    style:
                                        ElevatedButton
                                            .styleFrom(

                                      backgroundColor:
                                          Colors.red,
                                    ),

                                    onPressed:
                                        () {

                                      deleteNotif(
                                        n["id"],
                                      );
                                    },

                                    child:
                                        const Text(
                                      "Delete",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
