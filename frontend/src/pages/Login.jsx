import { Navigate } from "react-router-dom";
import { useAuth } from "react-oidc-context";

// Login is now a single button. Clicking it hands off to Cognito, which sends
// the user to Google. When they come back authenticated, we bounce to home.
export default function Login() {
  const auth = useAuth();

  if (auth.isLoading) return <p className="muted">Loading…</p>;
  if (auth.isAuthenticated) return <Navigate to="/" replace />;

  return (
    <>
      <h1>Sign in</h1>
      <p className="muted">Use your Google account to upload and manage videos.</p>
      <button onClick={() => auth.signinRedirect()}>Sign in with Google</button>
      {auth.error && <p className="error">{auth.error.message}</p>}
    </>
  );
}
