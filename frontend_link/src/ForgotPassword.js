import React, { useState } from "react";
import axios from "axios";

function ForgotPassword() {

  const [step, setStep] = useState(1);

  const [email, setEmail] = useState("");

  const [otp, setOtp] = useState("");

  const [newPassword, setNewPassword] =
    useState("");

  const [confirmPassword, setConfirmPassword] =
    useState("");

  // =====================================
  // SEND OTP
  // =====================================

  const handleSendOtp = async () => {

    if (!email) {

      alert("Entrer votre email");
      return;
    }

    try {

      await axios.post(

        "http://127.0.0.1:8000/authe/send-otp/",

        {

          email:
            email.trim().toLowerCase()
        }
      );

      alert(
        "OTP envoyé (voir terminal Django)"
      );

      setStep(2);

    } catch (err) {

      alert(

        err.response?.data?.error ||

        "Erreur"
      );
    }
  };

  // =====================================
  // VERIFY OTP
  // =====================================

  const handleVerifyOtp = async () => {

    if (
      !otp ||
      !newPassword ||
      !confirmPassword
    ) {

      alert("Remplir les champs");
      return;
    }

    if (newPassword !== confirmPassword) {

      alert("Passwords différents");
      return;
    }

    try {

      await axios.post(

        "http://127.0.0.1:8000/authe/verify-otp/",

        {

          email:
            email.trim().toLowerCase(),

          otp,

          password:
            newPassword
        }
      );

alert(
  "Mot de passe modifié"
);

// AUTO LOGIN
const loginRes = await axios.post(

  "http://127.0.0.1:8000/authe/logine/",

  {

    email:
      email.trim().toLowerCase(),

    password:
      newPassword
  }
);

// SAVE TOKEN
localStorage.setItem(

  "token",

  loginRes.data.access
);

// SAVE USER
const normalizedUser = {

  ...loginRes.data.user,

  role: String(
    loginRes.data.user.role || ""
  )
    .trim()
    .toUpperCase(),
};

localStorage.setItem(

  "user",

  JSON.stringify(
    normalizedUser
  )
);

// REDIRECT
const role =
  normalizedUser.role;

if (role === "ADMIN") {

  window.location.href =
    "/dashboard";
}

else if (
  role === "COMPTABLE"
) {

  window.location.href =
    "/reports";
}

else if (
  role === "AUDITEUR"
) {

  window.location.href =
    "/logs";
}

else if (
  role === "CLIENT"
) {

  window.location.href =
    "/profile";
}

else {

  window.location.href = "/";
}

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

        <h2>
          Mot de passe oublié
        </h2>

        {/* ========================= */}
        {/* STEP 1 */}
        {/* ========================= */}

        {step === 1 && (

          <>

            <input

              type="email"

              placeholder="Email"

              value={email}

              onChange={(e) =>
                setEmail(e.target.value)
              }
            />

            <button
              onClick={handleSendOtp}
            >
              Envoyer OTP
            </button>

          </>
        )}

        {/* ========================= */}
        {/* STEP 2 */}
        {/* ========================= */}

        {step === 2 && (

          <>

            <input

              type="text"

              placeholder="OTP"

              value={otp}

              onChange={(e) =>
                setOtp(e.target.value)
              }
            />

            <input

              type="password"

              placeholder="Nouveau mot de passe"

              value={newPassword}

              onChange={(e) =>
                setNewPassword(
                  e.target.value
                )
              }
            />

            <input

              type="password"

              placeholder="Confirmer mot de passe"

              value={confirmPassword}

              onChange={(e) =>
                setConfirmPassword(
                  e.target.value
                )
              }
            />

            <button
              onClick={handleVerifyOtp}
            >
              Vérifier OTP
            </button>

          </>
        )}

      </div>

    </div>
  );
}

export default ForgotPassword;