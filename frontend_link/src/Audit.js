import React, { useEffect, useState } from "react";
import API from "./api";

function Audit() {
  const [data, setData] = useState([]);

  useEffect(() => {
    API.get("audit/")
      .then(res => setData(res.data))
      .catch(err => console.log(err));
  }, []);

  return (
    <div>
      <h2>Transactions</h2>

      {data.map(t => (
        <div key={t.id}>
          {t.montant}
        </div>
      ))}
    </div>
  );
}

export default Audit;