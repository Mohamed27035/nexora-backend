import React, {
  useEffect,
  useState
} from "react";

import API from "./api";

import Navbar from "./Navbar";

import { Bar } from "react-chartjs-2";

import "chart.js/auto";

function Reports() {

  // ==========================
  // STATES
  // ==========================
  const [stats, setStats] =
    useState({});

  const [chartData,
    setChartData
  ] = useState([]);

  const [start, setStart] =
    useState("");

  const [end, setEnd] =
    useState("");

  const [finance, setFinance] =
    useState({});

  // ==========================
  // FETCH
  // ==========================
  const fetchData = () => {

    API.get(
      `reporting/stats/?start=${start}&end=${end}`
    )

      .then(res =>
        setStats(res.data)
      );

    API.get(
      `reporting/chart/?start=${start}&end=${end}`
    )

      .then(res =>
        setChartData(res.data)
      );

    API.get(
      `reporting/financial/?start=${start}&end=${end}`
    )

      .then(res =>
        setFinance(res.data)
      );
  };

  useEffect(() => {

    fetchData();

  }, []);

  // ==========================
  // PDF DOWNLOAD
  // ==========================
  const downloadPDF = async () => {

    try {

      const response =
        await API.get(

          "reporting/export-transactions-pdf/",

          {
            responseType: "blob"
          }
        );

      const url =
        window.URL.createObjectURL(
          new Blob([response.data])
        );

      const link =
        document.createElement("a");

      link.href = url;

      link.setAttribute(

        "download",

        "transactions_report.pdf"
      );

      document.body.appendChild(
        link
      );

      link.click();

    } catch (err) {

      console.log(err);

      alert(
        "PDF download error"
      );
    }
  };

  // ==========================
  // EXCEL DOWNLOAD
  // ==========================
  const downloadExcel = async () => {

    try {

      const response =
        await API.get(

          "reporting/export-transactions-excel/",

          {
            responseType: "blob"
          }
        );

      const url =
        window.URL.createObjectURL(
          new Blob([response.data])
        );

      const link =
        document.createElement("a");

      link.href = url;

      link.setAttribute(

        "download",

        "transactions_report.xlsx"
      );

      document.body.appendChild(
        link
      );

      link.click();

    } catch (err) {

      console.log(err);

      alert(
        "Excel download error"
      );
    }
  };

  // ==========================
  // ACTIVITY CHART
  // ==========================
  const data = {

    labels: chartData.map(
      i => i.day
    ),

    datasets: [

      {
        label:
          "Activity per day",

        data: chartData.map(
          i => i.count
        ),
      }
    ]
  };

  // ==========================
  // FINANCIAL CHART
  // ==========================
  const financeChart = {

    labels: [

      "Deposit",

      "Withdraw"
    ],

    datasets: [

      {
        label:
          "Money Flow",

        data: [

          finance.deposit || 0,

          finance.withdraw || 0
        ],
      }
    ]
  };

  return (

    <>
      <Navbar />

      <div
        style={{
          padding: "30px",
          marginTop: "80px"
        }}
      >

        {/* TITLE */}
        <h2>
          📊 Reports
        </h2>

        <br />

        {/* DOWNLOADS */}
        <div
          style={{
            display: "flex",
            gap: "15px",
            marginBottom: "25px"
          }}
        >

          <button
            onClick={downloadPDF}
          >

            Download PDF

          </button>

          <button
            onClick={downloadExcel}
          >

            Download Excel

          </button>

        </div>

        {/* FILTERS */}
        <div
          style={{
            display: "flex",
            gap: "10px",
            marginBottom: "20px",
            flexWrap: "wrap"
          }}
        >

          <input
            type="date"

            value={start}

            onChange={e =>
              setStart(
                e.target.value
              )
            }
          />

          <input
            type="date"

            value={end}

            onChange={e =>
              setEnd(
                e.target.value
              )
            }
          />

          <button
            onClick={fetchData}
          >

            Filter

          </button>

        </div>

        {/* KPI */}
        <div
          style={{
            display: "grid",

            gridTemplateColumns:
              "repeat(auto-fit,minmax(180px,1fr))",

            gap: "15px",

            marginBottom: "30px"
          }}
        >

          <div className="card-box">

            Total {stats.total}

          </div>

          <div className="card-box">

            Create {stats.create}

          </div>

          <div className="card-box">

            Update {stats.update}

          </div>

          <div className="card-box">

            Delete {stats.delete}

          </div>

          <div className="card-box">

            Login {stats.login}

          </div>

        </div>

        {/* FINANCIAL */}
        <div
          style={{
            marginBottom: "35px"
          }}
        >

          <h3>
            💰 Financial
          </h3>

          <br />

          <p>
            Deposit:
            {" "}
            {finance.deposit || 0}
          </p>

          <br />

          <p>
            Withdraw:
            {" "}
            {finance.withdraw || 0}
          </p>

          <br />

          <p>
            Balance:
            {" "}
            {finance.balance || 0}
          </p>

        </div>

        {/* CHART 1 */}
        <div
          style={{
            width: "100%",
            maxWidth: "800px",
            marginBottom: "40px"
          }}
        >

          <Bar data={data} />

        </div>

        {/* CHART 2 */}
        <div
          style={{
            width: "100%",
            maxWidth: "800px"
          }}
        >

          <Bar
            data={financeChart}
          />

        </div>

      </div>
    </>
  );
}

export default Reports;