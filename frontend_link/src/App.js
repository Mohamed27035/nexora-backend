import React from "react";

import {
  BrowserRouter,
  Routes,
  Route
} from "react-router-dom";

import Dashboard from "./Dashboard";
import Users from "./Users";
import AddUser from "./AddUser";
import Reports from "./Reports";
import Logs from "./Logs";
import Logine from "./Logine";
import Profile from "./Profile";
import MyLogs from "./MyLogs";
import Transactions from "./Transactions";
import Settings from "./Settings";
import KYC from "./KYC";
import ProtectedRoute from "./ProtectedRoute";
import AdminKYC from "./AdminKYC";
import Timeline from "./Timeline";

// NEW
import RegisterAdmin from "./RegisterAdmin";
import ForgotPassword from "./ForgotPassword";

function App() {

  return (

    <BrowserRouter>

      <Routes>

        {/* LOGIN */}
        <Route
          path="/"
          element={<Logine />}
        />

        {/* REGISTER ADMIN */}
        <Route
          path="/register"
          element={<RegisterAdmin />}
        />

        {/* FORGOT PASSWORD */}
        <Route
          path="/forgot-password"
          element={<ForgotPassword />}
        />

        {/* DASHBOARD */}
        <Route
          path="/dashboard"
          element={
            <ProtectedRoute
              roles={["ADMIN"]}
            >
              <Dashboard />
            </ProtectedRoute>
          }
        />

        {/* USERS */}
        <Route
          path="/users"
          element={
            <ProtectedRoute
              roles={["ADMIN"]}
            >
              <Users />
            </ProtectedRoute>
          }
        />

        {/* ADD USER */}
        <Route
          path="/add-user"
          element={
            <ProtectedRoute
              roles={["ADMIN"]}
            >
              <AddUser />
            </ProtectedRoute>
          }
        />
<Route
  path="/timeline"
  element={<Timeline />}
/>
        {/* REPORTS */}
        <Route
          path="/reports"
          element={
            <ProtectedRoute
              roles={[
                "ADMIN",
                "COMPTABLE"
              ]}
            >
              <Reports />
            </ProtectedRoute>
          }
        />

        {/* LOGS */}
        <Route
          path="/logs"
          element={
            <ProtectedRoute
              roles={[
                "ADMIN",
                "AUDITEUR"
              ]}
            >
              <Logs />
            </ProtectedRoute>
          }
        />

        {/* PROFILE */}
        <Route
          path="/profile"
          element={
            <ProtectedRoute
              roles={[
                "ADMIN",
                "CLIENT",
                "AUDITEUR",
                "COMPTABLE"
              ]}
            >
              <Profile />
            </ProtectedRoute>
          }
        />

        {/* MY LOGS */}
        <Route
          path="/my-logs"
          element={
            <ProtectedRoute
              roles={["CLIENT"]}
            >
              <MyLogs />
            </ProtectedRoute>
          }
        />

        {/* TRANSACTIONS */}
        <Route
          path="/transactions"
          element={
            <ProtectedRoute
              roles={[
                "ADMIN",
                "CLIENT",
                "COMPTABLE"
              ]}
            >
              <Transactions />
            </ProtectedRoute>
          }
        />
<Route
  path="/admin-kyc"
  element={<AdminKYC />}
/>
        {/* SETTINGS */}
        <Route
          path="/settings"
          element={
            <ProtectedRoute
              roles={[
                "ADMIN",
                "CLIENT",
                "COMPTABLE",
                "AUDITEUR"
              ]}
            >
              <Settings />
            </ProtectedRoute>
          }
        />
        <Route
  path="/kyc"
  element={<KYC />}
/>

      </Routes>

    </BrowserRouter>
  );
}

export default App;