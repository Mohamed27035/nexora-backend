// Sidebar.js
import React from "react";
import "./css/Sidebar.css";

function Sidebar() {
  const user = JSON.parse(localStorage.getItem("user") || "null");
  const role = user?.role;

  return (
    <div className="sidebar">
      <h2 className="logo">MyApp</h2>

      <ul>
        <li onClick={() => window.location.href="/dashboard"}>Dashboard</li>

        {role === "ADMIN" && (
          <>
            <li onClick={() => window.location.href="/users"}>Users</li>
            <li onClick={() => window.location.href="/add-user"}>Add User</li>
            <li onClick={() => window.location.href="/logs"}>Logs</li>
          </>
        )}

        {role === "CLIENT" && (
          <>
            <li onClick={() => window.location.href="/profile"}>My Profile</li>
            <li onClick={() => window.location.href="/my-logs"}>My Activity</li>
          </>
        )}

        {role === "AUDITEUR" && (
          <>
            <li onClick={() => window.location.href="/logs"}>Logs</li>
          </>
        )}

        {role === "COMPTABLE" && (
          <>
            <li onClick={() => window.location.href="/reports"}>Reports</li>
          </>
        )}

        <li onClick={() => {
          localStorage.clear();
          window.location.href = "/";
        }}>
          Logout
        </li>
      </ul>
    </div>
  );
}

export default Sidebar;