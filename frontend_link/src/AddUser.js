import React, { useState, useEffect } from "react";

import "./css/AddUser.css";

import API from "./api";

import Navbar from "./Navbar";

import { useNavigate } from "react-router-dom";

function AddUser() {

  const navigate = useNavigate();

  // ==========================
  // STATES
  // ==========================
  const [nom, setNom] = useState("");

  const [prenom, setPrenom] = useState("");

  const [telephone, setTelephone] = useState("");

  const [bio, setBio] = useState("");

  const [email, setEmail] = useState("");

  const [password, setPassword] = useState("");

  const [role, setRole] = useState("");

  const user = JSON.parse(
    localStorage.getItem("user") || "null"
  );

  // ==========================
  // SECURITY
  // ==========================
  useEffect(() => {

    if (!user || user.role !== "ADMIN") {
      navigate("/");
    }

  }, [user, navigate]);

  // ==========================
  // ADD USER
  // ==========================
  const handleAdd = () => {

    if (
      !nom ||
      !email ||
      !password ||
      !role
    ) {

      alert("Remplir tous les champs ❗");

      return;
    }

    API.post("/users/create/", {

      nom,
      prenom,
      telephone,
      bio,
      email,
      password,
      role

    })

    .then((res) => {

      console.log("SUCCESS =>", res.data);

      alert("User ajouté ✅");

      navigate("/users");
    })

    .catch((err) => {

      console.log(
        "ERROR =>",
        err.response?.data
      );

      alert("Erreur lors de la création");
    });
  };

  return (

    <>
      <Navbar />

      <div className="add-user-page">

        <div className="add-user-card">

          <h2>
            👤 Add User
          </h2>

          {/* NOM */}
          <input
            type="text"

            placeholder="Nom"

            value={nom}

            onChange={(e) =>
              setNom(e.target.value)
            }
          />

          {/* PRENOM */}
          <input
            type="text"

            placeholder="Prenom"

            value={prenom}

            onChange={(e) =>
              setPrenom(e.target.value)
            }
          />

          {/* TELEPHONE */}
          <input
            type="text"

            placeholder="Téléphone"

            value={telephone}

            onChange={(e) =>
              setTelephone(e.target.value)
            }
          />

          {/* EMAIL */}
          <input
            type="email"

            placeholder="Email"

            value={email}

            onChange={(e) =>
              setEmail(e.target.value)
            }
          />

          {/* PASSWORD */}
          <input
            type="password"

            placeholder="Password"

            value={password}

            onChange={(e) =>
              setPassword(e.target.value)
            }
          />

          {/* ROLE */}
          <select
            value={role}

            onChange={(e) =>
              setRole(e.target.value)
            }
          >

            <option value="">
              Choisir un rôle
            </option>

            <option value="ADMIN">
              Administrateur
            </option>

            <option value="AUDITEUR">
              Auditeur
            </option>

            <option value="CLIENT">
              Client
            </option>

            <option value="COMPTABLE">
              Comptable
            </option>

          </select>

          {/* BIO */}
          <textarea
            placeholder="Bio"

            value={bio}

            onChange={(e) =>
              setBio(e.target.value)
            }
          />

          {/* BUTTON */}
          <button onClick={handleAdd}>
            Ajouter
          </button>

        </div>

      </div>
    </>
  );
}

export default AddUser;