// The OIDC library (react-oidc-context) owns the real session and token
// storage. This little module just mirrors the current ID token in memory so
// the plain api.js fetch helper (which isn't a React component and can't use
// hooks) can read it. App.jsx keeps this in sync as auth state changes.
let _token = null;

export const setToken = (t) => {
  _token = t || null;
};
export const getToken = () => _token;
export const clearToken = () => {
  _token = null;
};
