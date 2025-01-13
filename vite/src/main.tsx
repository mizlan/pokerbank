import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router";
import "./index.css";
import App from "./App.tsx";
import Login from "./Login.tsx";
import { SWRConfig } from "swr";
import RootLayout from "./RootLayout.tsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SWRConfig
      value={{
        refreshInterval: 15000,
        fetcher: async (resource) => {
          const resp = await fetch(resource);
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
          <Route element={<RootLayout />}>
            <Route index element={<App />} />
            <Route path="/login" element={<Login />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </SWRConfig>
  </StrictMode>,
);
