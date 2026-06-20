import React, { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import API, { createWebSocketUrl } from "./api";
import "./css/navbar.css";

const navigationByRole = {
  ADMIN: [
    { label: "Dashboard", path: "/dashboard" },
    { label: "Profile", path: "/profile" },
    { label: "Users", path: "/users" },
    { label: "Reports", path: "/reports" },
    { label: "Logs", path: "/logs" },
    { label: "Transactions", path: "/transactions" },
    { label: "KYC Review", path: "/admin-kyc" },
    { label: "Timeline", path: "/timeline" },
  ],
  COMPTABLE: [
    { label: "Reports", path: "/reports" },
    { label: "Transactions", path: "/transactions" },
    { label: "Timeline", path: "/timeline" },
  ],
  AUDITEUR: [
    { label: "Logs", path: "/logs" },
    { label: "Timeline", path: "/timeline" },
  ],
  CLIENT: [
    { label: "Profile", path: "/profile" },
    { label: "My Logs", path: "/my-logs" },
    { label: "Transactions", path: "/transactions" },
    { label: "KYC", path: "/kyc" },
    { label: "Timeline", path: "/timeline" },
  ],
};

function Navbar() {
  const navigate = useNavigate();
  const location = useLocation();
  const user = JSON.parse(localStorage.getItem("user") || "null");
  const role = String(user?.role || "").toUpperCase();

  const [notifications, setNotifications] = useState([]);
  const [showNotifications, setShowNotifications] = useState(false);

  useEffect(() => {
    let socket;

    const fetchNotifications = async () => {
      try {
        const response = await API.get("notifications/my/");
        setNotifications(Array.isArray(response.data) ? response.data : []);
      } catch (error) {
        console.log("Notifications error =>", error);
      }
    };

    fetchNotifications();
    const intervalId = window.setInterval(fetchNotifications, 10000);

    try {
      socket = new WebSocket(createWebSocketUrl("ws/notifications/"));
      socket.onmessage = () => {
        fetchNotifications();
      };
    } catch (error) {
      console.log("WebSocket setup error =>", error);
    }

    return () => {
      window.clearInterval(intervalId);

      if (socket) {
        socket.close();
      }
    };
  }, []);

  const navItems = navigationByRole[role] || [];
  const unreadCount = notifications.filter((item) => !item.is_read).length;

  const initials = useMemo(() => {
    const fullName = [user?.prenom, user?.nom].filter(Boolean).join(" ").trim();
    const source = fullName || user?.email || "Nexora";
    return source
      .split(/\s+/)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase())
      .join("");
  }, [user]);

  const handleLogout = () => {
    localStorage.clear();
    navigate("/", { replace: true });
  };

  const markAsRead = async (id) => {
    try {
      await API.post(`notifications/read/${id}/`);
      setNotifications((current) =>
        current.map((item) =>
          item.id === id ? { ...item, is_read: true } : item
        )
      );
    } catch (error) {
      console.log("Mark notification error =>", error);
    }
  };

  const deleteNotification = async (id) => {
    try {
      await API.delete(`notifications/delete/${id}/`);
      setNotifications((current) => current.filter((item) => item.id !== id));
    } catch (error) {
      console.log("Delete notification error =>", error);
    }
  };

  return (
    <header className="navbar">
      <div className="navbar-brand" onClick={() => navigate("/dashboard")}>
        <div className="navbar-brand-mark">N</div>
        <div>
          <strong>Nexora</strong>
          <span>Control center</span>
        </div>
      </div>

      <nav className="navbar-links">
        {navItems.map((item) => (
          <button
            key={item.path}
            type="button"
            className={
              location.pathname === item.path
                ? "navbar-link navbar-link-active"
                : "navbar-link"
            }
            onClick={() => navigate(item.path)}
          >
            {item.label}
          </button>
        ))}
      </nav>

      <div className="navbar-actions">
        <div className="navbar-notification-wrapper">
          <button
            type="button"
            className="navbar-icon-button"
            onClick={() => setShowNotifications((current) => !current)}
            aria-label="Notifications"
          >
            <span className="navbar-icon-bell" />
            {unreadCount > 0 ? (
              <span className="navbar-badge">{unreadCount}</span>
            ) : null}
          </button>

          {showNotifications ? (
            <div className="navbar-notification-panel">
              <div className="navbar-notification-head">
                <strong>Notifications</strong>
                <span>{unreadCount} unread</span>
              </div>

              {notifications.length === 0 ? (
                <p className="navbar-empty-state">No notifications for now.</p>
              ) : (
                notifications.map((notification) => (
                  <article
                    key={notification.id}
                    className={
                      notification.is_read
                        ? "navbar-notification-item"
                        : "navbar-notification-item navbar-notification-item-unread"
                    }
                  >
                    <button
                      type="button"
                      className="navbar-notification-content"
                      onClick={() => {
                        markAsRead(notification.id);

                        if (notification.route) {
                          navigate(notification.route);
                          setShowNotifications(false);
                        }
                      }}
                    >
                      <strong>{notification.title}</strong>
                      <p>{notification.message}</p>
                    </button>

                    <button
                      type="button"
                      className="navbar-delete-button"
                      onClick={() => deleteNotification(notification.id)}
                    >
                      Remove
                    </button>
                  </article>
                ))
              )}
            </div>
          ) : null}
        </div>

        <button
          type="button"
          className="navbar-icon-button"
          onClick={() => navigate("/settings")}
          aria-label="Settings"
        >
          <span className="navbar-icon-cog" />
        </button>

        <div className="navbar-profile-chip">
          <div className="navbar-profile-avatar">{initials || "N"}</div>
          <div className="navbar-profile-meta">
            <strong>{user?.nom || user?.email || "User"}</strong>
            <span>{role || "SESSION"}</span>
          </div>
        </div>

        <button type="button" className="navbar-logout" onClick={handleLogout}>
          Logout
        </button>
      </div>
    </header>
  );
}

export default Navbar;
