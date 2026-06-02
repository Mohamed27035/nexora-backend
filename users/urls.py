from django.urls import path

from .views import (
    get_activity_timeline,
)
from .views import (

    get_users,
    get_user,
    create_user,
    update_user,
    delete_user,

    suspend_user,
    activate_user,
    ban_user,
    change_role,
    reset_password,

    get_logs,
    get_audit,

    get_my_profile,
    update_my_profile,

    get_my_logs,

    get_my_alerts,

    get_my_stats,

    detect_anomalies,
    detect_suspicious_behavior,

    track_login,
    forgot_password,
    check_admin_exists
    
)
from .views import register_client


urlpatterns = [

    # USERS
    path(
        '',
        get_users
    ),

    path(
        '<int:id>/',
        get_user
    ),

    path(
        'create/',
        create_user
    ),

    path(
        'update/<int:id>/',
        update_user
    ),

    path(
        'delete/<int:id>/',
        delete_user
    ),

    # PROFILE
    path(
        'profile/',
        get_my_profile
    ),

    path(
        'profile/update/',
        update_my_profile
    ),

    # LOGS
    path(
        'logs/',
        get_logs
    ),

    path(
        'my-logs/',
        get_my_logs
    ),

    # ALERTS
    path(
        'me/alerts/',
        get_my_alerts
    ),

    # AUDIT
    path(
        'audit/',
        get_audit
    ),

    # STATS
    path(
        'stats/',
        get_my_stats
    ),

    # SECURITY
    path(
        'detect-anomalies/',
        detect_anomalies
    ),

    path(
        'detect-behavior/',
        detect_suspicious_behavior
    ),

    # LOGIN
    path(
        'track-login/',
        track_login
    ),

    # ADMIN CHECK
    path(
        'check-admin/',
        check_admin_exists
    ),
    path(
    'me/',
    get_my_profile
),

path(
    'suspend/<int:id>/',
    suspend_user
),

path(
    'activate/<int:id>/',
    activate_user
),

path(
    'ban/<int:id>/',
    ban_user
),

path(
    'change-role/<int:id>/',
    change_role
),

path(
    'reset-password/<int:id>/',
    reset_password
),

path(

    "forgot-password/",

    forgot_password,

    name="forgot_password"
),
path(
    "timeline/",
    get_activity_timeline
),

path(
    "register/",
    register_client
),

]


