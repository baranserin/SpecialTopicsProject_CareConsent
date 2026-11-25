import React from "react";
import ReactDOM from "react-dom/client";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <header className="topbar">
      <div className="brand">CareConsent</div>
    </header>
    <main className="content">
      <h1>Patient dashboard</h1>
      <p className="muted">Project setup is ready.</p>
    </main>
  </React.StrictMode>,
);
