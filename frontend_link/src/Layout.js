import React from "react";
import Navbar from "./Navbar";

function Layout({ children }) {
  return (
    <>
      <Navbar />

      <div className="dashboard-layout">
        <div className="sidebar">
          <h2 className="logo">MyApp</h2>

          <ul>
            <li onClick={() => window.location.href="/dashboard"}>Dashboard</li>
            <li onClick={() => window.location.href="/users"}>Users</li>
            <li onClick={() => window.location.href="/logs"}>Logs</li>
            <li onClick={() => window.location.href="/reports"}>Reports</li>
            <li onClick={() => window.location.href="/transactions"}>Transactions</li>
          </ul>
        </div>

        <div className="main-content">
          {children}
        </div>
      </div>
    </>
  );
}

export default Layout;
