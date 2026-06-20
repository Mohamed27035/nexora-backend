// KYC.js

import React, {
  useEffect,
  useState
} from "react";

import API from "./api";

import Navbar from "./Navbar";

import "./css/KYC.css";

function KYC() {

  // ==========================
  // STATES
  // ==========================
  const [idDocument,
    setIdDocument
  ] = useState(null);

  const [selfie,
    setSelfie
  ] = useState(null);

  const [requests,
    setRequests
  ] = useState([]);

  // ==========================
  // FETCH MY KYC
  // ==========================
  const fetchKYC = () => {

    API.get("kyc/my/")

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
  // SUBMIT
  // ==========================
  const submitKYC = async () => {

    if (!idDocument || !selfie) {

      alert(
        "Upload documents"
      );

      return;
    }

    try {

      const formData = new FormData();

      formData.append(
        "id_document",
        idDocument
      );

      formData.append(
        "selfie",
        selfie
      );

      await API.post(

        "kyc/submit/",

        formData,

        {
          headers: {
            "Content-Type":
              "multipart/form-data"
          }
        }
      );

      alert(
        "KYC submitted"
      );

      setIdDocument(null);

      setSelfie(null);

      fetchKYC();

    } catch (err) {

      console.log(err);

      alert(
        err.response?.data?.error ||
        "KYC error"
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

      <div className="kyc-page">

        <h2>
          🪪 KYC Verification
        </h2>

        {/* FORM */}
        <div className="kyc-form">

          <h3>
            Submit documents
          </h3>

          <input
            type="file"

            onChange={(e) =>
              setIdDocument(
                e.target.files[0]
              )
            }
          />

          <input
            type="file"

            onChange={(e) =>
              setSelfie(
                e.target.files[0]
              )
            }
          />

          <button
            onClick={submitKYC}
          >

            Submit KYC

          </button>

        </div>

        {/* REQUESTS */}
        <div>

          <h3>
            My Requests
          </h3>

          <br />

          {requests.length === 0 ? (

            <p>
              No requests
            </p>

          ) : (

            requests.map((k) => (

              <div
                key={k.id}
                className="kyc-card"
              >

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

              </div>

            ))
          )}

        </div>

      </div>
    </>
  );
}

export default KYC;