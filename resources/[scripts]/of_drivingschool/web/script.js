(() => {
    "use strict";

    const body = document.body;
    const panel = document.querySelector(".result");
    const title = document.querySelector(".result__title");
    const reason = document.querySelector(".result__reason");
    const category = document.querySelector(".result__category");

    const hide = () => {
        body.classList.remove("is-visible", "is-failed");
        panel.setAttribute("aria-hidden", "true");
    };

    const show = (payload) => {
        if (!payload || (payload.Result !== "approved" && payload.Result !== "failed")) {
            hide();
            return;
        }

        const approved = payload.Result === "approved";
        title.textContent = approved ? "APROVADO" : "REPROVADO";
        reason.textContent = String(payload.Reason || (approved
            ? "Você foi aprovado na prova prática."
            : "A prova prática não foi concluída."));
        category.textContent = `CNH CATEGORIA ${String(payload.Category || "B").toUpperCase()}`;

        body.classList.toggle("is-failed", !approved);
        body.classList.add("is-visible");
        panel.setAttribute("aria-hidden", "false");
    };

    window.addEventListener("message", (event) => {
        const payload = event.data;
        if (!payload || typeof payload !== "object") {
            hide();
            return;
        }

        if (payload.Action === "showResult") {
            show(payload);
        } else if (payload.Action === "hideResult") {
            hide();
        }
    });

    window.addEventListener("error", hide);
    hide();
})();
