const statusElement = document.getElementById("vampire-status");
const ringElement = statusElement.querySelector(".vampire-ring");
const countElement = statusElement.querySelector(".vampire-count");

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action !== "vampire") return;

    statusElement.classList.toggle("is-visible", Boolean(data.visible));
    statusElement.classList.toggle("is-active", Boolean(data.active));

    const progress = Math.max(0, Math.min(1, Number(data.progress) || 0));
    ringElement.style.setProperty("--vampire-progress", `${progress * 360}deg`);
    countElement.textContent = `${Number(data.charges) || 0}/${Number(data.maximum) || 0}`;
});
