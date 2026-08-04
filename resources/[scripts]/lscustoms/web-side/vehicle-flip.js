(() => {
    "use strict";

    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "lscustoms";

    async function nui(name, payload = {}) {
        const response = await fetch(`https://${resource}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(payload)
        });
        const text = await response.text();
        try {
            return text ? JSON.parse(text) : {};
        } catch (_) {
            return { success: true };
        }
    }

    function injectButton() {
        const controls = document.querySelector(".of-mechanic-controls");
        if (!controls || controls.querySelector("[data-vehicle-flip]")) return;

        const button = document.createElement("button");
        button.type = "button";
        button.className = "of-mechanic-control";
        button.dataset.vehicleFlip = "true";
        button.textContent = "DESVIRAR VEICULO";
        button.addEventListener("click", async (event) => {
            event.preventDefault();
            event.stopPropagation();
            button.disabled = true;
            button.textContent = "VALIDANDO...";
            try {
                await nui("Close");
                const result = await nui("MechanicFlip");
                if (result && result.success === false) {
                    console.warn("[lscustoms/flip]", result.message || "Acao recusada.");
                }
            } catch (error) {
                console.error("[lscustoms/flip]", error);
            } finally {
                button.disabled = false;
                button.textContent = "DESVIRAR VEICULO";
            }
        });
        controls.appendChild(button);
    }

    document.addEventListener("DOMContentLoaded", injectButton);
    window.addEventListener("message", (event) => {
        if (event.data && (event.data.Action === "Open" || event.data.Action === "MechanicCart")) {
            window.setTimeout(injectButton, 0);
        }
    });
})();
