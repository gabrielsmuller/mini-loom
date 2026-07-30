import { useEffect, useState } from "react";
import { api, uploadToS3 } from "../api";

export default function Upload() {
  const [title, setTitle] = useState("");
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [shareUrl, setShareUrl] = useState("");
  const [copied, setCopied] = useState(false);
  const [videos, setVideos] = useState([]);

  const copyLink = async () => {
    await navigator.clipboard.writeText(shareUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const loadVideos = async () => {
    try {
      setVideos(await api.listVideos());
    } catch {
      /* ignore list errors on this minimal page */
    }
  };

  useEffect(() => {
    loadVideos();
  }, []);

  const MAX_BYTES = 200 * 1024 * 1024; // 200 MB — must match the backend cap

  const submit = async (e) => {
    e.preventDefault();
    if (!file) return;
    // Fail fast on oversized files instead of uploading 200MB just to be rejected.
    if (file.size > MAX_BYTES) {
      setError("That file is over the 200 MB limit.");
      return;
    }
    setError("");
    setShareUrl("");
    setBusy(true);
    try {
      // Step 1: create the record, get a pre-signed POST back.
      const { id, upload_url, upload_fields } = await api.createVideo(title, file.name);
      // Step 2: browser POSTs the file straight to S3 (never through the API).
      await uploadToS3(upload_url, upload_fields, file);

      const link = `${window.location.origin}/v/${id}`;
      setShareUrl(link);
      setTitle("");
      setFile(null);
      e.target.reset();
      loadVideos();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this video? This can't be undone.")) return;
    try {
      await api.deleteVideo(id);
      loadVideos();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <>
      <h1>Upload a video</h1>
      <form onSubmit={submit}>
        <label htmlFor="title">Title</label>
        <input
          id="title"
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />

        <label htmlFor="file">Video file</label>
        <input
          id="file"
          type="file"
          accept="video/*"
          onChange={(e) => setFile(e.target.files[0] || null)}
          required
        />

        {error && <p className="error">{error}</p>}

        <button type="submit" disabled={busy || !file}>
          {busy ? "Uploading…" : "Upload"}
        </button>
      </form>

      {shareUrl && (
        <div className="notice">
          Shareable link: <a href={shareUrl}>{shareUrl}</a>{" "}
          <button className="link" onClick={copyLink}>
            {copied ? "copied!" : "copy"}
          </button>
        </div>
      )}

      <h1 style={{ marginTop: "2rem" }}>Your videos</h1>
      {videos.length === 0 ? (
        <p className="muted">Nothing uploaded yet.</p>
      ) : (
        <ul className="video-list">
          {videos.map((v) => (
            <li key={v.id}>
              <a href={`/v/${v.id}`}>{v.title}</a>{" "}
              <span className="muted">· {v.views} views</span>{" "}
              <button className="link" onClick={() => handleDelete(v.id)}>
                delete
              </button>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
