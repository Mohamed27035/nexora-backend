import React, { useEffect, useState } from "react";
import API from "./api";
import Navbar from "./Navbar";
import "./css/Profile.css";

function Profile() {

  const [user, setUser] = useState(null);

  useEffect(() => {

    API.get("users/me/")
      .then((res) => {
        setUser(res.data);
      })
      .catch((err) => {
        console.log(err);
      });

  }, []);

  // ==========================
  // ROLE STYLE
  // ==========================
  const getRoleClass = (role) => {

    const r = String(role || "").toUpperCase();

    if (r === "ADMIN") return "admin";
    if (r === "AUDITEUR") return "auditeur";
    if (r === "COMPTABLE") return "comptable";
    if (r === "CLIENT") return "client";

    return "default";
  };

  if (!user) {

    return (

      <>
        <Navbar />

        <div className="profile-loading">
          Loading...
        </div>
      </>
    );
  }

  return (

    <>
      <Navbar />

      <div className="profile-page">

        <div className="profile-card">

          {/* HEADER */}
          <div className="profile-header">

            <div className="avatar-box">

              {user.avatar ? (

                <img
                  src={user.avatar}
                  alt="avatar"
                  className="avatar-image"
                />

              ) : (

                <div className="avatar-placeholder">
                  👤
                </div>

              )}

            </div>

            <h2>
              My Profile
            </h2>

            <p>
              Personal informations
            </p>

          </div>

          {/* INFOS */}
          <div className="profile-info">

            <div className="profile-row">

              <span>
                👨 Nom
              </span>

              <strong>
                {user.nom || "N/A"}
              </strong>

            </div>

            <div className="profile-row">

              <span>
                👨‍💼 Prenom
              </span>

              <strong>
                {user.prenom || "N/A"}
              </strong>

            </div>

            <div className="profile-row">

              <span>
                📧 Email
              </span>

              <strong>
                {user.email || "N/A"}
              </strong>

            </div>

            <div className="profile-row">

              <span>
                📱 Téléphone
              </span>

              <strong>
                {user.telephone || "N/A"}
              </strong>

            </div>

            <div className="profile-row">

              <span>
                🛡️ State
              </span>

              <strong
                className={`role-badge-profile ${getRoleClass(user.role)}`}
              >
                {user.role}
              </strong>

            </div>

            <div className="profile-row bio-row">

              <span>
                📝 Bio
              </span>

              <p className="bio-text">
                {user.bio || "No bio"}
              </p>

            </div>

          </div>

        </div>

      </div>
    </>
  );
}

export default Profile;