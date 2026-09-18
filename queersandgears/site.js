const pages = [
  ["About", "about.html"],
  ["Mission", "mission.html"],
  ["Officers", "officers.html"],
  ["Calendar", "calendar.html"],
  ["Merch", "merch.html"],
  ["Contact", "contact.html"],
];

const currentPage = window.location.pathname.split("/").pop() || "index.html";
const pageLink = ([label, href]) =>
  `<a href="${href}"${currentPage === href ? ' aria-current="page"' : ""}>${label}</a>`;

document.querySelector("[data-site-header]").innerHTML = `
  <header class="site-header">
    <div class="container nav-wrap">
      <a class="brand" href="index.html" aria-label="Queers and Gears Motorcycle Alliance home">
        <span class="brand-mark"><img src="qag.jpg" alt=""></span>
      </a>
      <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-nav" aria-label="Open navigation">☰</button>
      <nav class="nav" id="site-nav" aria-label="Main navigation">
        ${pages.map(pageLink).join("")}
        <a href="join.html"${currentPage === "join.html" ? ' aria-current="page"' : ""}>Join</a>
      </nav>
    </div>
  </header>`;

document.querySelector("[data-site-footer]").innerHTML = `
  <footer class="site-footer">
    <div class="container">
      <div class="footer-simple">
        <div>
          <h3>Queers &amp; Gears Motorcycle Alliance</h3>
          <p>LGBTQ+ riders, passengers, future riders, and allies.</p>
        </div>
        <div class="footer-links">
          <a href="mailto:Queersandgearsmoto@gmail.com">Email</a>
          <a href="https://www.instagram.com/queersandgearsmotorcycle/" target="_blank" rel="noreferrer">Instagram</a>
          <a href="https://www.tiktok.com/@queersandgears" target="_blank" rel="noreferrer">TikTok</a>
          <a href="contact.html">More contact info</a>
        </div>
      </div>
      <p class="copyright">&copy; <span data-year></span> Queers &amp; Gears Motorcycle Alliance.</p>
    </div>
  </footer>`;

const toggle = document.querySelector(".nav-toggle");
const nav = document.querySelector(".nav");

if (toggle && nav) {
  toggle.addEventListener("click", () => {
    const open = nav.classList.toggle("open");
    toggle.setAttribute("aria-expanded", open);
    toggle.setAttribute("aria-label", open ? "Close navigation" : "Open navigation");
    toggle.textContent = open ? "×" : "☰";
  });
}

const year = document.querySelector("[data-year]");
if (year) year.textContent = new Date().getFullYear();
