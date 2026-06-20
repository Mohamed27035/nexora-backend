import React, {
  useEffect,
  useState
} from "react";

import API from "./api";

import Navbar from "./Navbar";

import "./css/Transactions.css";

function Transactions() {

  // ==========================
  // USER
  // ==========================
  const user = JSON.parse(
    localStorage.getItem("user") || "null"
  );

  const role = user?.role;

  // ==========================
  // STATES
  // ==========================
  const [transactions,
    setTransactions
  ] = useState([]);

  const [users, setUsers] =
    useState([]);

  const [montant, setMontant] =
    useState("");

  const [type, setType] =
    useState("DEPOSIT");

  const [receiver, setReceiver] =
    useState("");

  const [note, setNote] =
    useState("");

  const [proof, setProof] =
    useState(null);

  const [balance, setBalance] =
    useState(0);

  const [search, setSearch] =
    useState("");

  const [statusFilter,
    setStatusFilter
  ] = useState("ALL");

  const [typeFilter,
    setTypeFilter
  ] = useState("ALL");

  const [startDate,
    setStartDate
  ] = useState("");

  const [endDate,
    setEndDate
  ] = useState("");

  // ==========================
  // FETCH TRANSACTIONS
  // ==========================
  const fetchTransactions = () => {

    API.get(

      `transactions/?search=${search}&status=${statusFilter}&type=${typeFilter}&start=${startDate}&end=${endDate}`

    )

      .then((res) => {

        setTransactions(
          res.data
        );

        // 💰 BALANCE
        const total =
          res.data.reduce(

            (acc, t) =>

              t.type ===
                "DEPOSIT"

                ? acc +
                  Number(
                    t.montant
                  )

                : acc -
                  Number(
                    t.montant
                  ),

            0
          );

        setBalance(total);

      })

      .catch((err) => {

        console.log(err);
      });
  };

  // ==========================
  // FETCH USERS
  // ==========================
  useEffect(() => {

    fetchTransactions();

    API.get("users/")

      .then((res) => {

        setUsers(
          res.data
        );
      })

      .catch(() => {});

  }, [

    search,

    statusFilter,

    typeFilter,

    startDate,

    endDate

  ]);

  // ==========================
  // CREATE TRANSACTION
  // ==========================
  const createTransaction =
    async () => {

    if (!montant) {

      alert(
        "Entrer un montant"
      );

      return;
    }

    try {

      const formData =
        new FormData();

      formData.append(
        "montant",
        montant
      );

      formData.append(
        "type",
        type
      );

      formData.append(
        "note",
        note
      );

      if (
        type === "TRANSFER"
      ) {

        formData.append(
          "receiver",
          receiver
        );
      }

      if (proof) {

        formData.append(
          "proof",
          proof
        );
      }

      await API.post(

        "transactions/create/",

        formData,

        {
          headers: {
            "Content-Type":
              "multipart/form-data"
          }
        }
      );

      alert(
        "Transaction créée"
      );

      // RESET
      setMontant("");

      setReceiver("");

      setNote("");

      setType("DEPOSIT");

      setProof(null);

      // REFRESH
      fetchTransactions();

    } catch (err) {

      console.log(err);

      alert(
        "Erreur transaction"
      );
    }
  };

  // ==========================
  // APPROVE
  // ==========================
  const approveTransaction =
    async (id) => {

    const note = prompt(
      "Validation note"
    );

    try {

      await API.post(

        `transactions/approve/${id}/`,

        {
          note
        }
      );

      alert(
        "Transaction approved"
      );

      fetchTransactions();

    } catch (err) {

      console.log(err);

      alert(

        err.response?.data?.error ||

        "Approval error"
      );
    }
  };

  // ==========================
  // REJECT
  // ==========================
  const rejectTransaction =
    async (id) => {

    const note = prompt(
      "Reject reason"
    );

    try {

      await API.post(

        `transactions/reject/${id}/`,

        {
          note
        }
      );

      alert(
        "Transaction rejected"
      );

      fetchTransactions();

    } catch (err) {

      console.log(err);

      alert(

        err.response?.data?.error ||

        "Reject error"
      );
    }
  };

  return (

    <>
      <Navbar />

      <div className="transactions-page">

        {/* TITLE */}
        <h2 className="transactions-title">

          💳 Transactions

        </h2>

        {/* CARDS */}
        <div className="transactions-cards">

          <div className="transaction-card">

            <h3>
              Total Transactions
            </h3>

            <p>
              {transactions.length}
            </p>

          </div>

          <div className="transaction-card balance-card">

            <h3>
              Balance
            </h3>

            <p>
              {balance}
            </p>

          </div>

        </div>

        {/* FORM */}
        <div className="transaction-form">

          {/* MONTANT */}
          <input
            type="number"

            placeholder="Montant"

            value={montant}

            onChange={(e) =>
              setMontant(
                e.target.value
              )
            }
          />

          {/* TYPE */}
          <select
            value={type}

            onChange={(e) =>
              setType(
                e.target.value
              )
            }
          >

            <option value="DEPOSIT">
              Deposit
            </option>

            <option value="WITHDRAW">
              Withdraw
            </option>

            <option value="TRANSFER">
              Transfer
            </option>

          </select>

          {/* RECEIVER */}
          {type === "TRANSFER" && (

            <select
              value={receiver}

              onChange={(e) =>
                setReceiver(
                  e.target.value
                )
              }
            >

              <option value="">
                Select receiver
              </option>

              {users.map((u) => (

                <option
                  key={u.id}

                  value={u.id}
                >

                  {u.nom}

                </option>

              ))}

            </select>
          )}

          {/* NOTE */}
          <textarea
            placeholder="Note"

            value={note}

            onChange={(e) =>
              setNote(
                e.target.value
              )
            }
          />

          {/* PROOF */}
          <input
            type="file"

            onChange={(e) =>
              setProof(
                e.target.files[0]
              )
            }
          />

          {/* BUTTON */}
          <button
            onClick={
              createTransaction
            }
          >

            Add Transaction

          </button>

        </div>

        {/* FILTERS */}
        <div className="transactions-filters">

          {/* SEARCH */}
          <input
            type="text"

            placeholder="🔍 Search..."

            value={search}

            onChange={(e) =>
              setSearch(
                e.target.value
              )
            }
          />

          {/* STATUS */}
          <select
            value={statusFilter}

            onChange={(e) =>
              setStatusFilter(
                e.target.value
              )
            }
          >

            <option value="ALL">
              All Status
            </option>

            <option value="PENDING">
              Pending
            </option>

            <option value="APPROVED">
              Approved
            </option>

            <option value="REJECTED">
              Rejected
            </option>

          </select>

          {/* TYPE */}
          <select
            value={typeFilter}

            onChange={(e) =>
              setTypeFilter(
                e.target.value
              )
            }
          >

            <option value="ALL">
              All Types
            </option>

            <option value="DEPOSIT">
              Deposit
            </option>

            <option value="WITHDRAW">
              Withdraw
            </option>

            <option value="TRANSFER">
              Transfer
            </option>

          </select>

          {/* START DATE */}
          <input
            type="date"

            value={startDate}

            onChange={(e) =>
              setStartDate(
                e.target.value
              )
            }
          />

          {/* END DATE */}
          <input
            type="date"

            value={endDate}

            onChange={(e) =>
              setEndDate(
                e.target.value
              )
            }
          />

        </div>

        {/* LIST */}
        <div className="transactions-list">

          {transactions.length === 0 ? (

            <p>
              No transactions
            </p>

          ) : (

            transactions.map((t) => (

              <div
                key={t.id}

                className={`transaction-item ${t.status}`}
              >

                <div className="transaction-left">

                  <h4>
                    {t.type}
                  </h4>

                  <p>
                    Sender:
                    {" "}
                    {t.sender_name}
                  </p>

                  <p>
                    Receiver:
                    {" "}
                    {
                      t.receiver_name ||
                      "-"
                    }
                  </p>

                  {t.proof && (

                    <a
                      href={t.proof}

                      target="_blank"

                      rel="noreferrer"
                    >

                      📎 Proof

                    </a>

                  )}

                  <br />

                  <small>

                    {
                      new Date(
                        t.created_at
                      ).toLocaleString()
                    }

                  </small>

                </div>

                <div className="transaction-right">

                  <strong>
                    {t.montant}
                  </strong>

                  {t.validation_note && (

                    <p
                      style={{
                        marginTop: "8px",
                        fontSize: "13px",
                        color: "#666"
                      }}
                    >

                      📝 {t.validation_note}

                    </p>

                  )}

                  <span
                    className={`status ${t.status}`}
                  >

                    {t.status}

                  </span>

                  {/* ACTIONS */}
                  {(role === "ADMIN" ||
                    role === "COMPTABLE") &&

                    t.status ===
                      "PENDING" && (

                    <div className="transaction-actions">

                      <button
                        className="approve-btn"

                        onClick={() =>
                          approveTransaction(
                            t.id
                          )
                        }
                      >

                        Approve

                      </button>

                      <button
                        className="reject-btn"

                        onClick={() =>
                          rejectTransaction(
                            t.id
                          )
                        }
                      >

                        Reject

                      </button>

                    </div>
                  )}

                </div>

              </div>

            ))

          )}

        </div>

      </div>

    </>
  );
}

export default Transactions;