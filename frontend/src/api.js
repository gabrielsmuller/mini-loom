// Tiny API client for the Mini Loom backend.
// The one important detail (see PROJECT.md): the video file NEVER goes
// through this API. We POST /videos to get a pre-signed URL, then the
// browser PUTs the bytes straight to S3.

import { getToken } from "./auth";

const BASE = import.meta.env.VITE_API_URL || "http://localhost:8000";

async function request(path, { method = "GET", body, auth = false } = {}) {
  const headers = {};
  if (auth) headers["Authorization"] = `Bearer ${getToken()}`;

  let payload;
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }

  const res = await fetch(`${BASE}${path}`, { method, headers, body: payload });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      detail = (await res.json()).detail || detail;
    } catch {
      /* non-JSON error */
    }
    throw new Error(typeof detail === "string" ? detail : "Request failed");
  }
  return res.status === 204 ? null : res.json();
}

export const api = {
  // Step 1 of upload: create the record, get the pre-signed URL back.
  createVideo: (title, filename) =>
    request("/videos", { method: "POST", auth: true, body: { title, filename } }),

  listVideos: () => request("/videos", { auth: true }),

  watch: (id) => request(`/videos/${id}/watch`),

  // Removes the S3 object AND the DB row (owner-only, enforced server-side).
  deleteVideo: (id) => request(`/videos/${id}`, { method: "DELETE", auth: true }),
};

// Step 2 of upload: send the file directly to S3 as a multipart POST. We send
// the signed form fields first, then the file LAST (S3 requires that order).
// Don't set Content-Type — the browser adds the multipart boundary itself.
export async function uploadToS3(uploadUrl, fields, file) {
  const form = new FormData();
  Object.entries(fields).forEach(([k, v]) => form.append(k, v));
  form.append("file", file); // must be the last field

  const res = await fetch(uploadUrl, { method: "POST", body: form });
  if (!res.ok) throw new Error(`S3 upload failed (${res.status})`);
}
