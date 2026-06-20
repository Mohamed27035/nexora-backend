// AdminKYC.js

import React, {
  useEffect,
  useState
} from "react";

import API from "./api";

import Navbar from "./Navbar";

import "./css/AdminKYC.css";

function AdminKYC() {

  // ==========================
  // STATES
  // ==========================
  const [requests,
    setRequests
  ] = useState([]);

  // ==========================
  // FETCH
  // ==========================
  const fetchKYC = () => {

    API.get("kyc/all/")

      .then((res) => {

        setRequests(res.data);
      })

      .catch((err) => {

        console.log(err);
      });
  };

  useEffect(() => {

    fetchKYC();

  }, []);

  // ==========================
  // APPROVE
  // ==========================
  const approveKYC = async (id) => {

    const note = prompt(
      "Approval note"
    );

    try {

      await API.post(

        `kyc/approve/${id}/`,

        {
          note
        }
      );

      alert(
        "KYC approved"
      );

      fetchKYC();

    } catch (err) {

      console.log(err);

      alert(
        "Approve error"
      );
    }
  };

  // ==========================
  // REJECT
  // ==========================
  const rejectKYC = async (id) => {

    const note = prompt(
      "Reject reason"
    );

    try {

      await API.post(

        `kyc/reject/${id}/`,

        {
          note
        }
      );

      alert(
        "KYC rejected"
      );

      fetchKYC();

    } catch (err) {

      console.log(err);

      alert(
        "Reject error"
      );
    }
  };

  // ==========================
  // STATUS COLOR
  // ==========================
  const getStatusColor = (
    status
  ) => {

    if (status === "APPROVED")
      return "green";

    if (status === "REJECTED")
      return "red";

    return "orange";
  };

  return (

    <>
      <Navbar />

      <div className="admin-kyc-page">

        <h2>
          🛡️ Admin KYC
        </h2>

        <br />

        {requests.length === 0 ? (

          <p>
            No requests
          </p>

        ) : (

          requests.map((k) => (

            <div
              key={k.id}
              className="admin-kyc-card"
            >

              <h3>

                {k.utilisateur_name}

              </h3>

              <br />

              <p>

                <strong>
                  Status:
                </strong>

                <span
                  style={{
                    color:
                      getStatusColor(
                        k.status
                      ),
                    marginLeft: "10px"
                  }}
                >

                  {k.status}

                </span>

              </p>

              <br />

              <div className="kyc-images">

                <div>

                  <p>
                    ID Document
                  </p>

                  <br />

                  <img
                    src={k.id_document}

                    alt="id"
                  />

                </div>

                <div>

                  <p>
                    Selfie
                  </p>

                  <br />

                  <img
                    src={k.selfie}

                    alt="selfie"
                  />

                </div>

              </div>

              <br />

              <p>

                <strong>
                  Submitted:
                </strong>

                {" "}

                {
                  new Date(
                    k.submitted_at
                  ).toLocaleString()
                }

              </p>

              {k.review_note && (

                <>
                  <br />

                  <p>

                    <strong>
                      Note:
                    </strong>

                    {" "}

                    {k.review_note}

                  </p>
                </>

              )}

              <br />

              {k.status === "PENDING" && (

                <div className="kyc-actions">

                  <button
                    onClick={() =>
                      approveKYC(k.id)
                    }
                  >

                    Approve

                  </button>

                  <button
                    onClick={() =>
                      rejectKYC(k.id)
                    }
                  >

                    Reject

                  </button>

                </div>

              )}

            </div>

          ))
        )}

      </div>
    </>
  );
}

export default AdminKYC;