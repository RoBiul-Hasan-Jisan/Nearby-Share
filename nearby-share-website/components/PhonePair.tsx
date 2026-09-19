/**
 * The hero visual: two phones, no internet, one file travelling between them.
 * Pure CSS (see .pair in globals.css). The travelling file is the only
 * non-interactive motion on the page; it stops for users who prefer reduced motion.
 */
export default function PhonePair() {
  return (
    <div
      className="pair"
      role="img"
      aria-label="A phone sending a photo directly to a second phone, with no internet connection"
    >
      <div className="phone phone-a">
        <div className="screen">
          <p className="screen-title">Sending Files</p>
          <p className="screen-sub">Sending to: Sam&apos;s phone</p>
          <div className="mini-card">
            <p className="mini-name">holiday.jpg</p>
            <div className="bar">
              <span className="bar-fill" />
            </div>
            <p className="mini-meta">3.2 MB</p>
          </div>
          <p className="offline">
            <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true">
              <path
                d="M2 9a15 15 0 0 1 20 0M5.5 12.8a10 10 0 0 1 13 0M9 16.6a5 5 0 0 1 6 0M3 3l18 18"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.2"
                strokeLinecap="round"
              />
            </svg>
            No internet
          </p>
        </div>
      </div>

      <div className="link" aria-hidden="true">
        <span className="file" />
      </div>

      <div className="phone phone-b">
        <div className="screen">
          <p className="screen-title">Incoming File</p>
          <p className="screen-sub">Jo&apos;s phone wants to send:</p>
          <div className="mini-card">
            <p className="mini-name">holiday.jpg</p>
            <p className="mini-meta">3.2 MB</p>
          </div>
          <div className="mini-actions">
            <span className="mini-btn mini-btn-main">Accept</span>
            <span className="mini-btn">Reject</span>
          </div>
        </div>
      </div>
    </div>
  );
}
