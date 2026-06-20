import React, { useEffect, useMemo, useState } from "react";
import { Bar } from "react-chartjs-2";
import { useNavigate } from "react-router-dom";
import "chart.js/auto";

import API from "./api";
import Navbar from "./Navbar";
import "./css/Dashboard.css";

const quickLinks = [
  { label: "Users", path: "/users" },
  { label: "Transactions", path: "/transactions" },
  { label: "Reports", path: "/reports" },
  { label: "Logs", path: "/logs" },
  { label: "Profile", path: "/profile" },
];

function Dashboard() {
  const navigate = useNavigate();
  const user = JSON.parse(localStorage.getItem("user") || "null");
  const role = String(user?.role || "").toUpperCase();

  const [audit, setAudit] = useState(null);
  const [totalUsers, setTotalUsers] = useState(0);
  const [alerts, setAlerts] = useState([]);
  const [balance, setBalance] = useState(0);
  const [transactions, setTransactions] = useState([]);
  const [recentLogs, setRecentLogs] = useState([]);
  const [approvedCount, setApprovedCount] = useState(0);
  const [rejectedCount, setRejectedCount] = useState(0);
  const [pendingCount, setPendingCount] = useState(0);
  const [roleStats, setRoleStats] = useState({
    ADMIN: 0,
    COMPTABLE: 0,
    AUDITEUR: 0,
    CLIENT: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      navigate("/", { replace: true });
      return;
    }

    const loadDashboard = async () => {
      setLoading(true);

      try {
        const transactionsPromise = API.get("transactions/");
        const usersPromise = API.get("users/");
        const adminPromises =
          role === "ADMIN"
            ? Promise.allSettled([
                API.get("users/audit/"),
                API.get("users/me/alerts/"),
                API.get("users/logs/"),
              ])
            : Promise.resolve([]);

        const [transactionsResponse, usersResponse, adminResults] =
          await Promise.all([transactionsPromise, usersPromise, adminPromises]);

        const transactionItems = Array.isArray(transactionsResponse.data)
          ? transactionsResponse.data
          : [];
        const users = Array.isArray(usersResponse.data) ? usersResponse.data : [];

        setTransactions(transactionItems);
        setApprovedCount(
          transactionItems.filter((item) => item.status === "APPROVED").length
        );
        setRejectedCount(
          transactionItems.filter((item) => item.status === "REJECTED").length
        );
        setPendingCount(
          transactionItems.filter((item) => item.status === "PENDING").length
        );
        setBalance(
          transactionItems.reduce((sum, item) => {
            const amount = Number(item.montant || 0);
            return item.type === "DEPOSIT" ? sum + amount : sum - amount;
          }, 0)
        );

        setTotalUsers(users.length);
        setRoleStats({
          ADMIN: users.filter((item) => item.role === "ADMIN").length,
          COMPTABLE: users.filter((item) => item.role === "COMPTABLE").length,
          AUDITEUR: users.filter((item) => item.role === "AUDITEUR").length,
          CLIENT: users.filter((item) => item.role === "CLIENT").length,
        });

        if (Array.isArray(adminResults) && adminResults.length === 3) {
          const [auditResult, alertsResult, logsResult] = adminResults;
          setAudit(
            auditResult.status === "fulfilled" ? auditResult.value.data : null
          );
          setAlerts(
            alertsResult.status === "fulfilled"
              ? alertsResult.value.data?.alerts || []
              : []
          );
          setRecentLogs(
            logsResult.status === "fulfilled"
              ? (logsResult.value.data || []).slice(0, 5)
              : []
          );
        }
      } catch (error) {
        console.log("Dashboard error =>", error);
      } finally {
        setLoading(false);
      }
    };

    loadDashboard();
  }, [navigate, role, user]);

  const chartData = useMemo(() => {
    const totalDeposits = transactions
      .filter((item) => item.type === "DEPOSIT")
      .reduce((sum, item) => sum + Number(item.montant || 0), 0);

    const totalWithdrawals = transactions
      .filter((item) => item.type === "WITHDRAW")
      .reduce((sum, item) => sum + Number(item.montant || 0), 0);

    return {
      labels: ["Deposit", "Withdraw"],
      datasets: [
        {
          label: "Financial analytics",
          data: [totalDeposits, totalWithdrawals],
          backgroundColor: ["#1d4ed8", "#0f766e"],
          borderRadius: 16,
          borderSkipped: false,
        },
      ],
    };
  }, [transactions]);

  const summaryCards = [
    { label: "Net balance", value: `${balance} MRU`, tone: "primary" },
    { label: "Transactions", value: transactions.length, tone: "neutral" },
    { label: "Users", value: totalUsers, tone: "neutral" },
    { label: "Approved", value: approvedCount, tone: "success" },
    { label: "Pending", value: pendingCount, tone: "warning" },
    { label: "Rejected", value: rejectedCount, tone: "danger" },
  ];

  if (loading) {
    return <div className="dashboard-loading">Loading dashboard...</div>;
  }

  return (
    <div className="dashboard-shell">
      <Navbar />

      <main className="dashboard-page">
        <section className="dashboard-hero">
          <div className="dashboard-hero-copy">
            <span className="dashboard-tag">Nexora admin experience</span>
            <h1>Dashboard modernise pour la supervision quotidienne</h1>
            <p>
              Une vue plus claire, plus proche du mobile, avec une meilleure
              lecture des indicateurs, des alertes et des acces rapides.
            </p>

            <div className="dashboard-hero-actions">
              {quickLinks.map((item) => (
                <button
                  key={item.path}
                  type="button"
                  className="dashboard-quick-link"
                  onClick={() => navigate(item.path)}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          <div className="dashboard-hero-panel">
            <div className="dashboard-hero-top">
              <strong>Welcome back {user?.nom || "Admin"}</strong>
              <span>{role || "ADMIN"}</span>
            </div>

            <div className="dashboard-hero-metrics">
              <article>
                <span>Audit logs</span>
                <strong>{audit?.total_logs || 0}</strong>
              </article>
              <article>
                <span>Alerts</span>
                <strong>{alerts.length}</strong>
              </article>
              <article>
                <span>Role mix</span>
                <strong>{Object.values(roleStats).reduce((sum, item) => sum + item, 0)}</strong>
              </article>
            </div>
          </div>
        </section>

        <section className="dashboard-card-grid">
          {summaryCards.map((card) => (
            <article
              key={card.label}
              className={`dashboard-stat-card dashboard-stat-${card.tone}`}
            >
              <span>{card.label}</span>
              <strong>{card.value}</strong>
            </article>
          ))}
        </section>

        <section className="dashboard-content-grid">
          <div className="dashboard-panel dashboard-panel-chart">
            <div className="dashboard-panel-head">
              <div>
                <span className="dashboard-panel-kicker">Analytics</span>
                <h2>Financial activity</h2>
              </div>
            </div>
            <Bar
              data={chartData}
              options={{
                responsive: true,
                plugins: {
                  legend: {
                    display: false,
                  },
                },
              }}
            />
          </div>

          <div className="dashboard-panel">
            <div className="dashboard-panel-head">
              <div>
                <span className="dashboard-panel-kicker">Roles</span>
                <h2>Distribution</h2>
              </div>
            </div>

            <div className="dashboard-role-list">
              {Object.entries(roleStats).map(([name, count]) => (
                <div key={name} className="dashboard-role-item">
                  <div>
                    <strong>{name}</strong>
                    <span>Active accounts</span>
                  </div>
                  <b>{count}</b>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="dashboard-content-grid dashboard-content-grid-bottom">
          <div className="dashboard-panel">
            <div className="dashboard-panel-head">
              <div>
                <span className="dashboard-panel-kicker">Transactions</span>
                <h2>Recent activity</h2>
              </div>
            </div>

            <div className="dashboard-list">
              {transactions.slice(0, 5).map((item) => (
                <div key={item.id} className="dashboard-list-item">
                  <div>
                    <strong>{item.type}</strong>
                    <span>{item.date || "No date"}</span>
                  </div>
                  <div className="dashboard-list-meta">
                    <b>{item.montant}</b>
                    <em className={`dashboard-status dashboard-status-${String(item.status || "").toLowerCase()}`}>
                      {item.status}
                    </em>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="dashboard-panel">
            <div className="dashboard-panel-head">
              <div>
                <span className="dashboard-panel-kicker">Monitoring</span>
                <h2>Recent logs</h2>
              </div>
            </div>

            <div className="dashboard-list">
              {recentLogs.length === 0 ? (
                <div className="dashboard-empty">No logs available.</div>
              ) : (
                recentLogs.map((item) => (
                  <div key={item.id} className="dashboard-list-item">
                    <div>
                      <strong>{item.action}</strong>
                      <span>{item.user}</span>
                    </div>
                    <b>{new Date(item.date).toLocaleString()}</b>
                  </div>
                ))
              )}
            </div>
          </div>
        </section>

        {alerts.length > 0 ? (
          <section className="dashboard-alert-strip">
            <div>
              <span className="dashboard-panel-kicker">Alerts</span>
              <h2>Points requiring attention</h2>
            </div>

            <div className="dashboard-alert-list">
              {alerts.map((item, index) => (
                <article key={`${item}-${index}`} className="dashboard-alert-card">
                  {item}
                </article>
              ))}
            </div>
          </section>
        ) : null}
      </main>
    </div>
  );
}

export default Dashboard;
