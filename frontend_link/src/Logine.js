import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import API from "./api";
import "./css/Logine.css";

const redirectByRole = (role) => {
  switch (role) {
    case "ADMIN":
      return "/dashboard";
    case "COMPTABLE":
      return "/reports";
    case "AUDITEUR":
      return "/logs";
    case "CLIENT":
      return "/profile";
    default:
      return "/";
  }
};

function Logine() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const canSubmit = useMemo(() => {
    return email.trim().length > 0 && password.trim().length > 0 && !loading;
  }, [email, password, loading]);

  const handleLogin = async (event) => {
    event?.preventDefault();

    if (!email.trim() || !password.trim()) {
      setError("Renseignez votre email et votre mot de passe.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const response = await API.post("authe/logine/", {
        email: email.trim().toLowerCase(),
        password,
      });

      if (!response.data?.access || !response.data?.user) {
        throw new Error("Invalid login payload");
      }

      const normalizedUser = {
        ...response.data.user,
        role: String(response.data.user.role || "")
          .trim()
          .toUpperCase(),
      };

      localStorage.setItem("token", response.data.access);
      localStorage.setItem("user", JSON.stringify(normalizedUser));

      navigate(redirectByRole(normalizedUser.role), { replace: true });
    } catch (loginError) {
      setError(
        loginError.response?.data?.error ||
          loginError.response?.data?.detail ||
          "Connexion impossible pour le moment."
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-shell">
      <div className="login-orb login-orb-left" />
      <div className="login-orb login-orb-right" />

      <div className="login-layout">
        <section className="login-hero">
          <span className="login-badge">Nexora fintech workspace</span>
          <div className="login-brand-row">
            <div className="login-logo">N</div>
            <div>
              <h1>Bienvenue sur Nexora</h1>
              <p>
                Une interface d&apos;administration moderne pour le reporting,
                l&apos;audit, les transactions et le suivi KYC.
              </p>
            </div>
          </div>

          <div className="login-hero-grid">
            <article className="login-hero-card">
              <strong>Reporting</strong>
              <span>Vue claire sur les operations et les indicateurs.</span>
            </article>
            <article className="login-hero-card">
              <strong>Audit</strong>
              <span>Suivi des actions, alertes et controles sensibles.</span>
            </article>
            <article className="login-hero-card">
              <strong>Administration</strong>
              <span>Gestion des utilisateurs et validation des comptes.</span>
            </article>
          </div>

          <div className="login-trust-panel">
            <div>
              <strong>Acces securise</strong>
              <p>Session protegee, navigation role-based et experience fluide.</p>
            </div>
            <div className="login-trust-pill">Ready for teams</div>
          </div>
        </section>

        <section className="login-panel">
          <div className="login-panel-head">
            <span className="login-kicker">Connexion</span>
            <h2>Accedez a votre espace</h2>
            <p>
              Connectez-vous pour gerer les operations fintech et superviser les
              modules critiques.
            </p>
          </div>

          <form className="login-form" onSubmit={handleLogin}>
            <label className="login-field">
              <span>Adresse email</span>
              <input
                type="email"
                placeholder="nom@entreprise.com"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                autoComplete="email"
              />
            </label>

            <label className="login-field">
              <span>Mot de passe</span>
              <input
                type="password"
                placeholder="Votre mot de passe"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete="current-password"
              />
            </label>

            {error ? <div className="login-error">{error}</div> : null}

            <button className="login-submit" type="submit" disabled={!canSubmit}>
              {loading ? "Connexion en cours..." : "Se connecter"}
            </button>
          </form>

          <div className="login-links">
            <button
              type="button"
              className="login-link-button"
              onClick={() => navigate("/register")}
            >
              Creer compte ADMIN
            </button>
            <button
              type="button"
              className="login-link-button login-link-danger"
              onClick={() => navigate("/forgot-password")}
            >
              Mot de passe oublie ?
            </button>
          </div>

          <div className="login-side-note">
            <strong>Pourquoi cette nouvelle interface ?</strong>
            <p>
              Le web adopte maintenant la meme direction visuelle que le mobile:
              cartes profondes, contrastes nets, espaces mieux geres et hierarchy
              plus claire.
            </p>
          </div>
        </section>
      </div>
    </div>
  );
}

export default Logine;
