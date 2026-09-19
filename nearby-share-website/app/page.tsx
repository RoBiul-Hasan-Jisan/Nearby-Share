import Link from "next/link";
import Logo from "@/components/Logo";
import PhonePair from "@/components/PhonePair";
import { site } from "@/lib/config";

const steps = [
  {
    title: "Open the app on both phones",
    body: "Turn on Bluetooth and Wi-Fi on each phone. You don't need an internet connection.",
  },
  {
    title: "On the receiving phone, tap Receive",
    body: "The phone becomes visible to nearby senders and waits.",
  },
  {
    title: "On the sending phone, tap Send Files",
    body: "Nearby Share lists the phones that are ready to receive. Tap the one you want.",
  },
  {
    title: "Check that the codes match",
    body: "Both screens show the same code. If it matches, tap Accept Connection on both phones.",
  },
  {
    title: "Choose files and send",
    body: "Pick one file or many. The receiving phone sees the names and sizes and taps Accept. Both phones show progress until it's done.",
  },
];

const facts = [
  {
    term: "Works without internet",
    detail: "The two phones talk to each other over Bluetooth and Wi-Fi. No mobile data, no router, no signal needed.",
  },
  {
    term: "Send many files at once",
    detail: "Photos, videos, music, PDFs, documents, ZIP files and APKs. Select as many as you like in one go.",
  },
  {
    term: "The receiver always decides",
    detail: "Before anything moves, the receiving phone shows the file names and total size and asks Accept or Reject.",
  },
  {
    term: "See how it's going",
    detail: "Progress for the whole transfer and for each file, plus speed and time remaining.",
  },
  {
    term: "Cancel from either phone",
    detail: "Stop a transfer at any moment. Files you already have stay where they are.",
  },
  {
    term: "Easy to find afterwards",
    detail: "Received files go to Downloads > Nearby Share > Received. A history on each phone lists what was sent and received.",
  },
];

const faqs = [
  {
    q: "Does it use my mobile data?",
    a: "No. The phones connect to each other directly with Bluetooth and Wi-Fi. You don't need a data plan or a Wi-Fi network with internet, but Bluetooth and Wi-Fi should be switched on.",
  },
  {
    q: "Does the other person need the app too?",
    a: "Yes. One phone taps Receive and the other taps Send Files, so both need Nearby Share installed.",
  },
  {
    q: "Does it work on iPhone?",
    a: "Not yet. Nearby Share is for Android 8 and newer.",
  },
  {
    q: "Where do received files go?",
    a: "On Android 10 and newer they appear in your Downloads folder under Nearby Share > Received. On Android 9 and older they are kept in the app's own folder.",
  },
  {
    q: "Why does the app ask for permissions?",
    a: "Android requires permission to find and connect to nearby devices (Bluetooth and Nearby devices). On Android 11 and older it also asks for Location, because Android ties Bluetooth scanning to it. Nearby Share does not read or store your location.",
  },
  {
    q: "The transfer stopped. What now?",
    a: "Keep both phones close together and keep the app open while sending. If it fails, the app tells you why and lets you retry. Your original files are never deleted.",
  },
];

export default function Home() {
  return (
    <>
      <header className="site-header">
        <div className="wrap header-row">
          <Link href="/" className="brand" aria-label={`${site.name} home`}>
            <Logo />
            <span>{site.name}</span>
          </Link>
          <nav className="nav" aria-label="Main">
            <a href="#how">How it works</a>
            <a href="#safe">Safety</a>
            <a href="#faq">FAQ</a>
            <a href="#get" className="btn btn-small">
              Get the app
            </a>
          </nav>
        </div>
      </header>

      <main>
        <section className="hero wrap">
          <div className="hero-copy">
            <h1>Send files to the phone next to you. No internet needed.</h1>
            <p className="lead">
              Nearby Share moves photos, videos, documents and apps straight from one Android phone to another using
              Bluetooth and Wi-Fi. No mobile data, no account, no cloud.
            </p>
            <div className="actions">
              <a href="#get" className="btn">
                Get the app
              </a>
              <a href="#how" className="btn btn-ghost">
                See how it works
              </a>
            </div>
            <p className="fine">Both phones need the app. Works on Android 8 and newer.</p>
          </div>
          <PhonePair />
        </section>

        <section id="how" className="section wrap">
          <div className="section-head">
            <h2>How it works</h2>
            <p>Five steps, about a minute the first time.</p>
          </div>
          <ol className="steps">
            {steps.map((s, i) => (
              <li key={s.title}>
                <span className="step-n" aria-hidden="true">
                  {i + 1}
                </span>
                <div>
                  <h3>{s.title}</h3>
                  <p>{s.body}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>

        <section className="section wrap">
          <div className="section-head">
            <h2>What you can do with it</h2>
          </div>
          <dl className="facts">
            {facts.map((f) => (
              <div key={f.term} className="fact">
                <dt>{f.term}</dt>
                <dd>{f.detail}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section id="safe" className="safe">
          <div className="wrap safe-grid">
            <div>
              <h2>You decide who connects.</h2>
              <p className="safe-lead">
                Before any file moves, both phones show a short code. If the codes match, you are connected to the
                right phone. If they don&apos;t, tap Reject.
              </p>
              <ul className="safe-list">
                <li>The receiver always sees what is coming and chooses Accept or Reject.</li>
                <li>Files go straight from phone to phone. Nothing is uploaded to a server.</li>
                <li>No sign-up and no account.</li>
              </ul>
            </div>
            <div className="code-panel" role="img" aria-label="Example verification screen showing the code 482 913">
              <p className="code-q">Do the codes match?</p>
              <p className="code">482 913</p>
              <p className="code-note">Only continue if the code shown on both devices is identical.</p>
              <div className="code-actions" aria-hidden="true">
                <span className="mini-btn mini-btn-main">Accept Connection</span>
                <span className="mini-btn mini-btn-dark">Reject</span>
              </div>
              <p className="code-example">Example screen</p>
            </div>
          </div>
        </section>

        <section id="faq" className="section wrap">
          <div className="section-head">
            <h2>Questions</h2>
          </div>
          <div className="faq">
            {faqs.map((f) => (
              <details key={f.q}>
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
        </section>

        <section id="get" className="section wrap">
          <div className="get">
            <div>
              <h2>Get Nearby Share</h2>
              <p>
                {site.playStoreUrl
                  ? "Install it on both phones, then follow the five steps above."
                  : "The app isn't on Google Play yet. Check back soon."}
              </p>
            </div>
            {site.playStoreUrl ? (
              <a href={site.playStoreUrl} className="btn">
                Get it on Google Play
              </a>
            ) : (
              <span className="btn btn-disabled" aria-disabled="true">
                Coming soon to Google Play
              </span>
            )}
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="wrap footer-row">
          <p>
            {site.name}. {site.tagline}
          </p>
          <Link href="/privacy">Privacy policy</Link>
        </div>
      </footer>
    </>
  );
}
