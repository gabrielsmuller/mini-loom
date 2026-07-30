import { useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";
import { api } from "../api";

// Public watch page — no auth. Hitting the endpoint also increments views.
export default function Watch() {
  const { id } = useParams();
  const [video, setVideo] = useState(null);
  const [error, setError] = useState("");
  const [unavailable, setUnavailable] = useState(false);

  // Guard against the view count being incremented twice: React 18 StrictMode
  // runs effects twice in dev, and this effect has a side effect (views += 1).
  // We fetch once per video id, no matter how many times the effect runs.
  const fetchedFor = useRef(null);

  useEffect(() => {
    if (fetchedFor.current === id) return;
    fetchedFor.current = id;
    api
      .watch(id)
      .then(setVideo)
      .catch((err) => setError(err.message));
  }, [id]);

  if (error) return <p className="error">{error}</p>;
  if (!video) return <p className="muted">Loading…</p>;

  return (
    <>
      <h1>{video.title}</h1>
      <p className="muted">{video.views} views</p>
      {unavailable ? (
        // The DB row exists but the file is gone (e.g. auto-expired after 7 days).
        <p className="error">This video is no longer available.</p>
      ) : (
        <video
          src={video.video_url}
          controls
          autoPlay
          onError={() => setUnavailable(true)}
        />
      )}
    </>
  );
}
