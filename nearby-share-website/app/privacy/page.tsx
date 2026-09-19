import type { Metadata } from "next";
import Link from "next/link";
import Logo from "@/components/Logo";
import { site } from "@/lib/config";

export const metadata: Metadata = {
  title: `Privacy policy | ${site.name}`,
  description: `How ${site.name} handles your data.`,
};

export default function Privacy() {
  return (
    <>
      <header className="site-header">
        <div className="wrap header-row">
          <Link href="/" className="brand" aria-label={`${site.name} home`}>
            <Logo />
            <span>{site.name}</span>
          </Link>
          <nav className="nav" aria-label="Main">
            <Link href="/">Back to home</Link>
          </nav>
        </div>
      </header>

      <main className="wrap prose">
        <h1>Privacy policy</h1>
        <p className="fine">Last updated {site.updated}</p>

        <h2>The short version</h2>
        <p>
          {site.name} does not collect, upload, sell or share your personal data. There is no account, no sign-up and
          no server that receives your files. The app contains no analytics and no advertising.
        </p>

        <h2>How files are sent</h2>
        <p>
          Files travel directly from one phone to the other over Bluetooth and Wi-Fi, using Google&apos;s Nearby
          Connections, which is part of Google Play services. Google&apos;s own terms apply to that service. Nothing
          passes through us or through the internet.
        </p>

        <h2>What is stored on your phone</h2>
        <ul>
          <li>
            A transfer history: file names, sizes, the other phone&apos;s name, the date and whether it finished. You
            can clear it any time in Settings, and it is removed when you uninstall the app.
          </li>
          <li>A device name, if you choose to set a custom one.</li>
          <li>
            Files you receive, saved in Downloads &gt; Nearby Share &gt; Received (or the app&apos;s own folder on
            Android 9 and older). They are ordinary files that you can delete like any other.
          </li>
        </ul>

        <h2>Permissions</h2>
        <ul>
          <li>
            <strong>Nearby devices / Bluetooth:</strong> to find and connect to the other phone.
          </li>
          <li>
            <strong>Wi-Fi state:</strong> to check that Wi-Fi is on, and to transfer quickly.
          </li>
          <li>
            <strong>Location (Android 11 and older only):</strong> Android requires it for Bluetooth scanning on
            those versions. {site.name} does not read, store or share your location.
          </li>
        </ul>
        <p>
          Files you send are chosen with Android&apos;s own file picker. The app cannot see other files on your
          phone.
        </p>

        <h2>Changes</h2>
        <p>If this policy changes, the date at the top will change with it.</p>

        <h2>Contact</h2>
        <p>
          Questions? Email <a href={`mailto:${site.contactEmail}`}>{site.contactEmail}</a>.
        </p>
      </main>

      <footer className="site-footer">
        <div className="wrap footer-row">
          <p>
            {site.name}. {site.tagline}
          </p>
          <Link href="/">Home</Link>
        </div>
      </footer>
    </>
  );
}
