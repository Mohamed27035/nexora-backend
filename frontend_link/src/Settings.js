import React, { useEffect, useState } from "react";
import API from "./api";
import Navbar from "./Navbar";

function Settings() {

  const [form, setForm] = useState({
    nom: "",
    email: "",
    password: "",
    language: "fr"
  });

  const [loading, setLoading] = useState(true);

  // ==========================
  // LOAD USER
  // ==========================
  useEffect(() => {

    API.get("users/me/")
      .then((res) => {

        setForm((prev) => ({
          ...prev,
          nom: res.data.nom || "",
          email: res.data.email || "",
        }));

      })
      .catch((err) => {
        console.log(err);
      })
      .finally(() => {
        setLoading(false);
      });

  }, []);

  // ==========================
  // UPDATE
  // ==========================
  const handleSave = () => {

    const payload = {
      nom: form.nom,
      email: form.email,
    };

    // ✅ password optional
    if (form.password.trim() !== "") {
      payload.password = form.password;
    }

    API.put("users/me/update/", payload)

      .then(() => {

        alert("Settings updated ✅");

        // update localStorage
        const oldUser = JSON.parse(
          localStorage.getItem("user") || "{}"
        );

        localStorage.setItem(
          "user",
          JSON.stringify({
            ...oldUser,
            nom: form.nom,
            email: form.email,
          })
        );

      })

      .catch((err) => {
        console.log(err);
        alert("Erreur");
      });
  };

  // ==========================
  // LOADING
  // ==========================
  if (loading) {
    return (
      <div style={{ padding: "30px" }}>
        Loading...
      </div>
    );
  }

  return (
    <>
      <Navbar />

      <div
        style={{
          padding: "30px",
          marginTop: "70px",
          maxWidth: "600px",
          marginInline: "auto"
        }}
      >

        <div
          style={{
            background: "white",
            padding: "30px",
            borderRadius: "16px",
            boxShadow: "0 4px 15px rgba(0,0,0,0.08)"
          }}
        >

          <h2 style={{ marginBottom: "25px" }}>
            ⚙️ Paramètres
          </h2>

          {/* NOM */}
          <div style={{ marginBottom: "20px" }}>
            <label>Nom</label>

            <input
              type="text"
              value={form.nom}
              onChange={(e) =>
                setForm({
                  ...form,
                  nom: e.target.value
                })
              }
              style={inputStyle}
            />
          </div>

          {/* EMAIL */}
          <div style={{ marginBottom: "20px" }}>
            <label>Email</label>

            <input
              type="email"
              value={form.email}
              onChange={(e) =>
                setForm({
                  ...form,
                  email: e.target.value
                })
              }
              style={inputStyle}
            />
          </div>

          {/* PASSWORD */}
          <div style={{ marginBottom: "20px" }}>
            <label>Nouveau mot de passe</label>

            <input
              type="password"
              value={form.password}
              onChange={(e) =>
                setForm({
                  ...form,
                  password: e.target.value
                })
              }
              placeholder="********"
              style={inputStyle}
            />
          </div>

          {/* LANGUAGE */}
          <div style={{ marginBottom: "25px" }}>
            <label>Langue</label>

            <select
              value={form.language}
              onChange={(e) =>
                setForm({
                  ...form,
                  language: e.target.value
                })
              }
              style={inputStyle}
            >
              <option value="fr">
                Français
              </option>

              <option value="en">
                English
              </option>

              <option value="ar">
                العربية
              </option>

            </select>
          </div>

          {/* SAVE */}
          <button
            onClick={handleSave}
            style={{
              background: "#2563eb",
              color: "white",
              border: "none",
              padding: "12px 20px",
              borderRadius: "10px",
              cursor: "pointer",
              fontWeight: "bold"
            }}
          >
            Save Changes
          </button>

        </div>

      </div>
    </>
  );
}

// ==========================
// STYLE
// ==========================
const inputStyle = {
  width: "100%",
  padding: "12px",
  marginTop: "8px",
  borderRadius: "10px",
  border: "1px solid #d1d5db",
  fontSize: "15px",
  outline: "none",
};

export default Settings;