import React, { useState } from "react";
import axios from "axios";

function RegisterAdmin() {

  const [nom, setNom] = useState("");
  const [prenom, setPrenom] = useState("");
  const [telephone, setTelephone] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] =
    useState("");

  const [bio, setBio] = useState("");

  const handleRegister = async () => {

    if (
      !nom ||
      !email ||
      !password ||
      !confirmPassword
    ) {

      alert("Remplir les champs");
      return;
    }

    if (password !== confirmPassword) {

      alert("Passwords différents");
      return;
    }

    try {

      await axios.post(
        "http://127.0.0.1:8000/authe/register-admin/",
        {

          nom,
          prenom,
          telephone,

          email:
            email.trim().toLowerCase(),

          password,

          bio,

          role: "ADMIN"
        }
      );

      alert("Compte ADMIN créé");

      window.location.href = "/";

    } catch (err) {

      alert(
        err.response?.data?.error ||
        "Erreur"
      );
    }
  };

  return (

    <div className="login-container">

      <div className="login-box">

        <h2>Inscription Admin</h2>

        <input
          type="text"
          placeholder="Nom"
          value={nom}
          onChange={(e) =>
            setNom(e.target.value)
          }
        />

        <input
          type="text"
          placeholder="Prenom"
          value={prenom}
          onChange={(e) =>
            setPrenom(e.target.value)
          }
        />

        <input
          type="text"
          placeholder="Telephone"
          value={telephone}
          onChange={(e) =>
            setTelephone(e.target.value)
          }
        />

        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) =>
            setEmail(e.target.value)
          }
        />

        <textarea
          placeholder="Bio"
          value={bio}
          onChange={(e) =>
            setBio(e.target.value)
          }
        />

        <input
          type="password"
          placeholder="Mot de passe"
          value={password}
          onChange={(e) =>
            setPassword(e.target.value)
          }
        />

        <input
          type="password"
          placeholder="Confirmer mot de passe"
          value={confirmPassword}
          onChange={(e) =>
            setConfirmPassword(e.target.value)
          }
        />

        <button onClick={handleRegister}>
          Créer compte ADMIN
        </button>

      </div>

    </div>
  );
}

export default RegisterAdmin;