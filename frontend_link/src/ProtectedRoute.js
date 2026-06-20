import React from "react";
import { Navigate } from "react-router-dom";

function ProtectedRoute({ children, roles }) {
  const token = localStorage.getItem("token");
  const user = JSON.parse(localStorage.getItem("user") || "null");

  // ❌ غير مسجل دخول
  if (!token || !user) {
    return <Navigate to="/" replace />;
  }

  // ✅ توحيد role
  const currentRole = String(user.role || "")
    .trim()
    .toUpperCase();

  // ❌ ليس لديه صلاحية
  if (roles && !roles.includes(currentRole)) {

    if (currentRole === "ADMIN") {
      return <Navigate to="/dashboard" replace />;
    }

    if (currentRole === "COMPTABLE") {
      return <Navigate to="/reports" replace />;
    }

    if (currentRole === "AUDITEUR") {
      return <Navigate to="/logs" replace />;
    }

    if (currentRole === "CLIENT") {
      return <Navigate to="/profile" replace />;
    }

    return <Navigate to="/" replace />;
  }

  // ✅ مسموح
  return children;
}

export default ProtectedRoute;