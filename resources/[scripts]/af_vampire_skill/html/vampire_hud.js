const status = document.querySelector(".status");
const count = document.querySelector(".count");

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action !== "update") return;

    const progress = Math.max(0, Math.min(1, Number(data.progress) || 0));
    status.style.setProperty("--progress", String(progress));
    status.classList.toggle("active", Boolean(data.active));
    count.textContent = `${Number(data.charges) || 0}/${Number(data.maximum) || 0}`;
});
