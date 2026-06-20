import React, { useEffect, useState } from "react";
import API from "./api";
import { useNavigate } from "react-router-dom";
import Navbar from "./Navbar";
import "./css/Logs.css";

function Logs() {

  const navigate = useNavigate();

  const [logs, setLogs] = useState([]);

  const [search, setSearch] = useState("");

  const [actionFilter, setActionFilter] =
    useState("ALL");

  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");

  // ==========================
  // FETCH
  // ==========================
  const fetchLogs = () => {

  API.get(

    `users/logs/?search=${search}&start=${start}&end=${end}&action=${actionFilter}`

  )

  .then(res => setLogs(res.data))

  .catch(err => console.log(err));
};

 useEffect(() => {

  fetchLogs();

}, [
  search,
  actionFilter,
  start,
  end
]);

  // ==========================
  // FILTER
  // ==========================
  const filteredLogs = logs.filter(l =>

    (l.user || "")
      .toLowerCase()
      .includes(search.toLowerCase())

    ||

    (l.action || "")
      .toLowerCase()
      .includes(search.toLowerCase())
  );

  // ==========================
  // ACTION STYLE
  // ==========================
const getActionClass = (action) => {

  if (
    action === "CREATE_USER"
  ) return "create";

  if (
    action === "DELETE_USER"
  ) return "delete";

  if (
    action === "UPDATE_USER"
  ) return "update";

  if (
    action === "LOGIN"
  ) return "login";

  if (
    action === "SUSPEND_USER"
  ) return "warning";

  if (
    action === "BAN_USER"
  ) return "danger";

  if (
    action === "APPROVE_TRANSACTION"
  ) return "success";

  if (
    action === "REJECT_TRANSACTION"
  ) return "danger";

  return "default";
};

  return (

    <>
      <Navbar />

      <div className="logs-page">

        {/* HEADER */}
        <div className="logs-header">

          <h2>
            📜 Audit Logs
          </h2>

          <button
            onClick={() =>
              navigate("/dashboard")
            }
          >
            Dashboard
          </button>

        </div>

        {/* FILTERS */}
        <div className="logs-filters">

          <input
            type="text"
            placeholder="🔍 Search..."

            value={search}

            onChange={e =>
              setSearch(e.target.value)
            }
          />

<select
  value={actionFilter}

  onChange={e =>
    setActionFilter(e.target.value)
  }
>

  <option value="ALL">
    All
  </option>

  <option value="CREATE_USER">
    Create User
  </option>

  <option value="UPDATE_USER">
    Update User
  </option>

  <option value="DELETE_USER">
    Delete User
  </option>

  <option value="LOGIN">
    Login
  </option>

  <option value="SUSPEND_USER">
    Suspend User
  </option>

  <option value="BAN_USER">
    Ban User
  </option>

  <option value="ACTIVATE_USER">
    Activate User
  </option>

  <option value="RESET_PASSWORD">
    Reset Password
  </option>

  <option value="APPROVE_TRANSACTION">
    Approve Transaction
  </option>

  <option value="REJECT_TRANSACTION">
    Reject Transaction
  </option>

</select>

          <input
            type="date"
            value={start}

            onChange={e =>
              setStart(e.target.value)
            }
          />

          <input
            type="date"
            value={end}

            onChange={e =>
              setEnd(e.target.value)
            }
          />

          <button onClick={fetchLogs}>
            Apply
          </button>

        </div>

        {/* STATS */}
        <div className="logs-stats">

          <div className="logs-card">

            <h3>Total Logs</h3>

            <p>
              {logs.length}
            </p>

          </div>

          <div className="logs-card">

            <h3>Create Actions</h3>

            <p>
              {
                logs.filter(
                  l => l.action === "CREATE_USER"
                ).length
              }
            </p>

          </div>

          <div className="logs-card">

            <h3>Delete Actions</h3>

            <p>
              {
                logs.filter(
                  l => l.action === "DELETE_USER"
                ).length
              }
            </p>

          </div>

        </div>

        {/* TABLE */}
        <div className="logs-table-container">

          <table className="logs-table">

            <thead>

              <tr>

                <th>User</th>

                <th>Action</th>

                <th>Description</th>

                <th>Date</th>

              </tr>

            </thead>

            <tbody>

              {filteredLogs.map(l => (

                <tr
  key={l.id}

  className={
    l.is_suspicious
      ? "suspicious-row"
      : ""
  }
>

                  <td>
                    {l.user}
                  </td>

                  <td>

                    <span
                      className={`action-badge ${getActionClass(l.action)}`}
                    >
                      {l.action}
                    </span>

                  </td>

                  <td>

  {l.description}

  {l.is_suspicious && (

    <span className="security-badge">

      ⚠️ Suspicious

    </span>

  )}

</td>

                  <td>
                    {new Date(l.date)
                      .toLocaleString()}
                  </td>

                </tr>

              ))}

            </tbody>

          </table>

        </div>

      </div>
    </>
  );
}

export default Logs;