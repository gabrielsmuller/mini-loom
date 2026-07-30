import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "react-oidc-context";
import App from "./App.jsx";
import "./index.css";

// Cognito/OIDC settings. `authority` is the token issuer (from Terraform's
// cognito_issuer output); the library discovers the login + token endpoints
// from it automatically. We send the user straight to Google since that's our
// only identity provider.
const cognitoAuthConfig = {
  authority: import.meta.env.VITE_COGNITO_AUTHORITY,
  client_id: import.meta.env.VITE_COGNITO_CLIENT_ID,
  redirect_uri: window.location.origin,
  response_type: "code",
  scope: "openid email profile",
  extraQueryParams: { identity_provider: "Google" },
  // After the code is exchanged, strip ?code=&state= from the URL bar.
  onSigninCallback: () => {
    window.history.replaceState({}, document.title, window.location.pathname);
  },
};

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <AuthProvider {...cognitoAuthConfig}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </AuthProvider>
  </React.StrictMode>
);
