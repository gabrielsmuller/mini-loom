import { useEffect } from "react";
import { Routes, Route, Link, Navigate } from "react-router-dom";
import { useAuth } from "react-oidc-context";
import { setToken, clearToken } from "./auth";
import Login from "./pages/Login.jsx";
import Upload from "./pages/Upload.jsx";
import Watch from "./pages/Watch.jsx";

function Nav() {
  const auth = useAuth();

  // Full sign-out: clear our local session AND end the Cognito session, then
  // return to the app. Without the Cognito /logout hop, the session cookie
  // survives and "Sign in" would silently log you straight back in.
  const logout = () => {
    auth.removeUser();
    const domain = import.meta.env.VITE_COGNITO_DOMAIN;
    const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID;
    const returnTo = encodeURIComponent(window.location.origin);
    window.location.href = `${domain}/logout?client_id=${clientId}&logout_uri=${returnTo}`;
  };

  return (
    <nav>
      <Link to="/" className="brand">
        Mini Loom
      </Link>
      {auth.isAuthenticated ? (
        <>
          <Link to="/">Upload</Link>
          <button className="link" onClick={logout}>
            Log out
          </button>
        </>
      ) : (
        <Link to="/login">Log in</Link>
      )}
    </nav>
  );
}

// Guards routes that need a signed-in user. While the library is checking the
// existing session (or finishing a redirect), show a brief loading state.
function Protected({ children }) {
  const auth = useAuth();
  if (auth.isLoading) return <p className="muted">Loading…</p>;
  return auth.isAuthenticated ? children : <Navigate to="/login" replace />;
}

export default function App() {
  const auth = useAuth();

  // Mirror the ID token into auth.js so api.js can attach it as a Bearer.
  useEffect(() => {
    if (auth.isAuthenticated) setToken(auth.user?.id_token);
    else clearToken();
  }, [auth.isAuthenticated, auth.user]);

  return (
    <>
      <Nav />
      <div className="container">
        <Routes>
          <Route
            path="/"
            element={
              <Protected>
                <Upload />
              </Protected>
            }
          />
          <Route path="/login" element={<Login />} />
          <Route path="/v/:id" element={<Watch />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </>
  );
}
