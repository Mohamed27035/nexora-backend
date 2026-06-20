import React, { useEffect, useState } from "react";
import API from "./api";
import { useNavigate } from "react-router-dom";

function MyLogs() {
  const navigate = useNavigate();

  const [logs, setLogs] = useState([]);
  const [search, setSearch] = useState("");

  useEffect(() => {
    API.get("users/me/logs/")
      .then(res => setLogs(res.data))
      .catch((err) => {
        if (err.response?.status === 401) {
          localStorage.clear();
          navigate("/");
        }
      });
  }, [navigate]);

  const filtered = logs.filter(l =>
    (l.action || "").toLowerCase().includes(search.toLowerCase()) ||
    (l.description || "").toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div style={{ padding: "20px" }}>
      <h2>My Activity</h2>

      <input
        type="text"
        placeholder="Search..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ padding: "10px", marginBottom: "10px" }}
      />

      {filtered.length === 0 ? (
        <p>No activity</p>
      ) : (
        filtered.map(l => (
          <div key={l.id}>
            <b>{l.action}</b>
            <p>{l.description}</p>
            <small>{new Date(l.date).toLocaleString()}</small>
          </div>
        ))
      )}
    </div>
  );
}

export default MyLogs; 


