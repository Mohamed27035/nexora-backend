import React, { useEffect, useState } from "react";

import API from "./api";

import "./css/Users.css";

import { useNavigate } from "react-router-dom";

import Navbar from "./Navbar";

function Users() {

  const navigate = useNavigate();

  // ==========================
  // STATES
  // ==========================
  const [users, setUsers] = useState([]);

  const [editingUser, setEditingUser] =
    useState(null);

  const [search, setSearch] =
    useState("");

  const [currentPage, setCurrentPage] =
    useState(1);

  const usersPerPage = 5;

  // ==========================
  // FETCH USERS
  // ==========================
  useEffect(() => {

    fetchUsers();

  }, []);

  const fetchUsers = () => {

    API.get("users/")

      .then((res) => {

        setUsers(

          Array.isArray(res.data)

            ? res.data

            : []
        );
      })

      .catch((err) => {

        console.log(err);

        if (
          err.response?.status === 401
        ) {

          localStorage.clear();

          navigate("/");
        }
      });
  };

  // ==========================
  // DELETE USER
  // ==========================
  const handleDelete = (id) => {

    if (
      !window.confirm(
        "Supprimer cet utilisateur ?"
      )
    ) return;

    API.delete(
      `users/delete/${id}/`
    )

    .then(() => {

      fetchUsers();

    })

    .catch((err) =>
      console.log(err)
    );
  };

  // ==========================
  // UPDATE USER
  // ==========================
  const handleUpdate = () => {

    API.put(

      `users/update/${editingUser.id}/`,

      editingUser
    )

    .then(() => {

      setEditingUser(null);

      fetchUsers();

    })

    .catch((err) =>
      console.log(err)
    );
  };

  // ==========================
  // SUSPEND USER
  // ==========================
  const suspendUser = async (id) => {

    try {

      await API.post(
        `users/suspend/${id}/`
      );

      fetchUsers();

    } catch (err) {

      console.log(err);
    }
  };

  // ==========================
  // ACTIVATE USER
  // ==========================
  const activateUser = async (id) => {

    try {

      await API.post(
        `users/activate/${id}/`
      );

      fetchUsers();

    } catch (err) {

      console.log(err);
    }
  };

  // ==========================
  // BAN USER
  // ==========================
  const banUser = async (id) => {

    try {

      await API.post(
        `users/ban/${id}/`
      );

      fetchUsers();

    } catch (err) {

      console.log(err);
    }
  };

  // ==========================
  // FILTER USERS
  // ==========================
  const filteredUsers = users.filter(

    (u) =>

      u.nom
        ?.toLowerCase()
        .includes(
          search.toLowerCase()
        )

      ||

      u.email
        ?.toLowerCase()
        .includes(
          search.toLowerCase()
        )
  );

  // ==========================
  // PAGINATION
  // ==========================
  const indexOfLast =

    currentPage * usersPerPage;

  const currentUsers =

    filteredUsers.slice(

      indexOfLast - usersPerPage,

      indexOfLast
    );

  return (

    <>
      <Navbar />

      <div className="dashboard-layout">

        {/* SIDEBAR */}
        <div className="sidebar">

          <h2 className="logo">
            MyApp
          </h2>

          <ul>

            <li
              onClick={() =>
                navigate("/dashboard")
              }
            >
              Dashboard
            </li>

            <li className="active">
              Users
            </li>

            <li
              onClick={() =>
                navigate("/add-user")
              }
            >
              Add User
            </li>

            <li
              onClick={() =>
                navigate("/logs")
              }
            >
              Logs
            </li>

          </ul>

        </div>

        {/* MAIN */}
        <div className="main-content">

          <h2>
            👥 Users Management
          </h2>

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

            className="search-input"
          />

          {/* TABLE */}
          <table className="users-table">

            <thead>

              <tr>

                <th>Status</th>

                <th>ID</th>

                <th>Nom</th>

                <th>Email</th>

                <th>Role</th>

                <th>Action</th>

              </tr>

            </thead>

            <tbody>

              {currentUsers.map((u) => (

                <tr key={u.id}>

                  {/* STATUS */}
                  <td>

                    {u.is_banned ? (

                      <span
                        className="role-badge danger"
                      >
                        BANNED
                      </span>

                    ) : u.is_suspended ? (

                      <span
                        className="role-badge warning"
                      >
                        SUSPENDED
                      </span>

                    ) : (

                      <span
                        className="role-badge success"
                      >
                        ACTIVE
                      </span>

                    )}

                  </td>

                  {/* ID */}
                  <td>
                    {u.id}
                  </td>

                  {/* NAME */}
                  <td>
                    {u.nom}
                  </td>

                  {/* EMAIL */}
                  <td>
                    {u.email}
                  </td>

                  {/* ROLE */}
                  <td>

                    <span
                      className={`role-badge ${u.role}`}
                    >

                      {u.role}

                    </span>

                  </td>

                  {/* ACTIONS */}
                  <td>

                    <button

                      className="edit-btn"

                      onClick={() =>
                        setEditingUser(u)
                      }
                    >

                      Edit

                    </button>

                    <button

                      className="delete-btn"

                      onClick={() =>
                        handleDelete(u.id)
                      }
                    >

                      Delete

                    </button>

                    <button

                      className="suspend-btn"

                      onClick={() =>
                        suspendUser(u.id)
                      }
                    >

                      Suspend

                    </button>

                    <button

                      className="activate-btn"

                      onClick={() =>
                        activateUser(u.id)
                      }
                    >

                      Activate

                    </button>

                    <button

                      className="ban-btn"

                      onClick={() =>
                        banUser(u.id)
                      }
                    >

                      Ban

                    </button>

                  </td>

                </tr>

              ))}

            </tbody>

          </table>

          {/* EDIT MODAL */}
          {editingUser && (

            <div className="modal">

              <div className="modal-box">

                <h3>
                  Edit User
                </h3>

                {/* NAME */}
                <input

                  value={editingUser.nom}

                  onChange={(e) =>

                    setEditingUser({

                      ...editingUser,

                      nom: e.target.value
                    })
                  }
                />

                {/* EMAIL */}
                <input

                  value={editingUser.email}

                  onChange={(e) =>

                    setEditingUser({

                      ...editingUser,

                      email: e.target.value
                    })
                  }
                />

                {/* ROLE */}
                <select

                  value={editingUser.role}

                  onChange={(e) =>

                    setEditingUser({

                      ...editingUser,

                      role: e.target.value
                    })
                  }
                >

                  <option value="ADMIN">
                    ADMIN
                  </option>

                  <option value="AUDITEUR">
                    AUDITEUR
                  </option>

                  <option value="COMPTABLE">
                    COMPTABLE
                  </option>

                  <option value="CLIENT">
                    CLIENT
                  </option>

                </select>

                {/* SAVE */}
                <button
                  onClick={handleUpdate}
                >
                  Save
                </button>

                {/* CANCEL */}
                <button
                  onClick={() =>
                    setEditingUser(null)
                  }
                >
                  Cancel
                </button>

              </div>

            </div>

          )}

        </div>

      </div>
    </>
  );
}

export default Users;