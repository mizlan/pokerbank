import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router";
import "./index.css";
import App from "./App.tsx";
import Login from "./Login.tsx";
import { SWRConfig } from "swr";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SWRConfig
      value={{
        refreshInterval: 15000,
        fetcher: async (resource) => {
          const API_URL = "http://localhost:6868";
          const url = new URL(resource, API_URL);
          const resp = await fetch(url, { credentials: "include" });
          const json = await resp.json();
          if (!resp.ok) {
            const error = new Error("An error occurred");
            error.info = json;
            error.status = resp.status;
            throw error;
          }
          return json;
        },
      }}
    >
      <BrowserRouter>
        <Routes>
          <Route index element={<App />} />
          <Route path="/login" element={<Login />} />
        </Routes>
      </BrowserRouter>
    </SWRConfig>
  </StrictMode>,
);
