import React, {
  useEffect,
  useState
} from "react";

import API from "./api";

import Navbar from "./Navbar";

function Timeline() {

  // ==========================
  // STATES
  // ==========================
  const [timeline,
    setTimeline
  ] = useState([]);

  // ==========================
  // FETCH
  // ==========================
  const fetchTimeline = () => {

    API.get(
      "users/timeline/"
    )

      .then((res) => {

        setTimeline(
          res.data
        );
      })

      .catch((err) => {

        console.log(err);
      });
  };

  useEffect(() => {

    fetchTimeline();

  }, []);

  // ==========================
  // COLORS
  // ==========================
  const getColor = (
    action
  ) => {

    if (
      action.includes("DELETE")
    ) {
      return "#ef4444";
    }

    if (
      action.includes("LOGIN")
    ) {
      return "#3b82f6";
    }

    if (
      action.includes("DEPOSIT")
    ) {
      return "#10b981";
    }

    if (
      action.includes("WITHDRAW")
    ) {
      return "#f59e0b";
    }

    return "#6b7280";
  };

  return (

    <>
      <Navbar />

      <div
        style={{
          padding: "30px",
          marginTop: "80px",
          minHeight: "100vh",
          background: "#f3f4f6"
        }}
      >

        <h2>
          📈 Activity Timeline
        </h2>

        <br />

        {timeline.length === 0 ? (

          <p>
            No activity found
          </p>

        ) : (

          timeline.map((item,
            index) => (

            <div
              key={index}

              style={{
                background: "white",

                padding: "20px",

                borderRadius: "14px",

                marginBottom: "20px",

                borderLeft:
                  `6px solid ${getColor(item.action)}`,

                boxShadow:
                  "0 4px 20px rgba(0,0,0,0.08)"
              }}
            >

              <div
                style={{
                  display: "flex",

                  justifyContent:
                    "space-between",

                  alignItems:
                    "center",

                  flexWrap: "wrap"
                }}
              >

                <div>

                  <h3>

                    {item.action}

                  </h3>

                  <p>

                    {
                      item.description
                    }

                  </p>

                  {item.status && (

                    <p>

                      <strong>
                        Status:
                      </strong>

                      {" "}

                      {item.status}

                    </p>
                  )}

                </div>

                <div>

                  <small>

                    {
                      new Date(
                        item.date
                      ).toLocaleString()
                    }

                  </small>

                </div>

              </div>

            </div>

          ))
        )}

      </div>
    </>
  );
}

export default Timeline;