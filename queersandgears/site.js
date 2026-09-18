const pages = [
  ["About", "about.html"],
  ["Rides", "calendar.html"],
  ["Join", "join.html"],
  ["Contact", "contact.html"],
];

const currentPage = window.location.pathname.split("/").pop() || "index.html";
const pageLink = ([label, href]) =>
  `<a href="${href}"${currentPage === href ? ' aria-current="page"' : ""}>${label}</a>`;

document.querySelector("[data-site-header]").innerHTML = `
  <header class="site-header">
    <div class="container nav-wrap">
      <a class="brand" href="index.html" aria-label="Queers and Gears home">
        <span class="brand-mark"><img src="qag.jpg" alt=""></span>
        <span>Queers &amp; Gears</span>
      </a>
      <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-nav" aria-label="Open navigation">☰</button>
      <nav class="nav" id="site-nav" aria-label="Main navigation">
        ${pages.map(pageLink).join("")}
      </nav>
    </div>
  </header>`;

document.querySelector("[data-site-footer]").innerHTML = `
  <footer class="site-footer">
    <div class="container footer-row">
      <div class="footer-links">
        <a href="mission.html">Mission</a>
        <a href="officers.html">Officers</a>
        <a href="merch.html">Merch</a>
        <a href="https://www.instagram.com/queersandgearsmotorcycle/" target="_blank" rel="noreferrer">Instagram</a>
        <a href="https://www.tiktok.com/@queersandgears" target="_blank" rel="noreferrer">TikTok</a>
      </div>
      <p class="copyright">&copy; <span data-year></span> Queers &amp; Gears</p>
    </div>
  </footer>`;

const toggle = document.querySelector(".nav-toggle");
const nav = document.querySelector(".nav");

toggle.addEventListener("click", () => {
  const open = nav.classList.toggle("open");
  toggle.setAttribute("aria-expanded", open);
  toggle.setAttribute("aria-label", open ? "Close navigation" : "Open navigation");
  toggle.textContent = open ? "×" : "☰";
});

document.querySelector("[data-year]").textContent = new Date().getFullYear();
