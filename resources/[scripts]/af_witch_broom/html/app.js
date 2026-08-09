const hud = document.getElementById("broomHud");
const speed = document.getElementById("speed");
const altitude = document.getElementById("altitude");
const flightState = document.getElementById("flightState");
const hoverStatus = document.getElementById("hoverStatus");
const boostStatus = document.getElementById("boostStatus");

const setVisible = (visible) => {
    document.documentElement.style.background = "transparent";
    document.body.classList.toggle("hud-active", visible);
    hud.classList.toggle("visible", visible);
    hud.setAttribute("aria-hidden", String(!visible));
};

const applyLayout = (layout = {}) => {
    const left = Math.max(0, Number(layout.left) || 24);
    const top = Math.max(0, Number(layout.top) || 110);
    const width = Math.max(220, Number(layout.width) || 270);
    const scale = Math.max(0.7, Math.min(1.2, Number(layout.scale) || 1));

    hud.style.setProperty("--broom-left", `${left}px`);
    hud.style.setProperty("--broom-top", `${top}px`);
    hud.style.setProperty("--broom-width", `${width}px`);
    hud.style.setProperty("--broom-scale", String(scale));
};

setVisible(false);

window.addEventListener("message", ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === "show") {
        applyLayout(data.layout);
        setVisible(true);
        return;
    }

    if (data.action === "hide") {
        setVisible(false);
        return;
    }

    if (data.action !== "update") return;

    speed.textContent = Math.max(0, Number(data.speed) || 0);
    altitude.textContent = Math.max(0, Number(data.altitude) || 0);
    hoverStatus.classList.toggle("active", Boolean(data.hover));
    boostStatus.classList.toggle("active", Boolean(data.boost));
    const cooldown = Math.max(0, Number(data.boostCooldown) || 0);
    boostStatus.textContent = data.boost
        ? "IMPULSO ATIVO"
        : data.boostReady === false
            ? `IMPULSO RECARREGANDO ${Math.ceil(cooldown / 1000)}s`
            : "IMPULSO PRONTO";
    flightState.textContent = data.landing ? "AGUARDANDO POUSO" : data.boost ? "IMPULSO MAGICO" : "VOO NATIVO ATIVO";
});

if (new URLSearchParams(window.location.search).has("preview")) {
    window.dispatchEvent(new MessageEvent("message", { data: { action: "show", layout: { left: 24, top: 110, width: 270, scale: 1 } } }));
    window.dispatchEvent(new MessageEvent("message", { data: { action: "update", speed: 84, altitude: 32, hover: true, boost: false, boostReady: true } }));
}
