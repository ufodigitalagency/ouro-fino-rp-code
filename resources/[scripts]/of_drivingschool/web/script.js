(() => {
    "use strict";

    const body = document.body;
    const resultPanel = document.querySelector(".result");
    const resultTitle = document.querySelector(".result__title");
    const resultReason = document.querySelector(".result__reason");
    const resultCategory = document.querySelector(".result__category");
    const checklistPanel = document.querySelector(".checklist");
    const checklistStage = document.querySelector(".checklist__stage span");
    const checklistInstruction = document.querySelector(".checklist__instruction");
    const checklistProgress = document.querySelector(".checklist__progress");
    const checklistSteps = Array.from(document.querySelectorAll(".checklist__step"));

    const stepCopy = [
        { pending: "Entrar no veículo", complete: "Entrou no veículo" },
        { pending: "Colocar o cinto", complete: "Colocou o cinto" },
        { pending: "Ligar o motor", complete: "Ligou o motor" },
        { pending: "Acender os faróis", complete: "Acendeu os faróis" }
    ];

    const checklistStates = Object.freeze({
        WAITING_FOR_DRIVER: { stage: 1, completed: 0, instruction: "ENTRE NO VEÍCULO" },
        WAITING_FOR_SEATBELT: { stage: 2, completed: 1, instruction: "COLOQUE O CINTO" },
        WAITING_FOR_ENGINE: { stage: 3, completed: 2, instruction: "LIGUE O MOTOR" },
        WAITING_FOR_LIGHTS: { stage: 4, completed: 3, instruction: "ACENDA OS FARÓIS" },
        READY_FOR_ROUTE: { stage: 4, completed: 4, instruction: "PRONTO PARA INICIAR O PERCURSO" }
    });

    let checklistCompleted = 0;
    let checklistGeneration = 0;

    const syncBodyVisibility = () => {
        body.classList.toggle("is-visible", body.classList.contains("has-result") || body.classList.contains("has-checklist"));
    };

    const hideResult = () => {
        body.classList.remove("has-result", "is-failed");
        resultPanel.setAttribute("aria-hidden", "true");
        syncBodyVisibility();
    };

    const hideChecklist = () => {
        checklistGeneration += 1;
        checklistCompleted = 0;
        body.classList.remove("has-checklist");
        checklistPanel.setAttribute("aria-hidden", "true");
        checklistSteps.forEach((step) => step.classList.remove("is-current", "is-complete", "is-pending", "is-just-completed"));
        syncBodyVisibility();
    };

    const showResult = (payload) => {
        if (!payload || (payload.Result !== "approved" && payload.Result !== "failed")) {
            hideResult();
            return;
        }

        hideChecklist();
        const approved = payload.Result === "approved";
        resultTitle.textContent = approved ? "APROVADO" : "REPROVADO";
        resultReason.textContent = String(payload.Reason || (approved
            ? "Você foi aprovado na prova prática."
            : "A prova prática não foi concluída."));
        resultCategory.textContent = `CNH CATEGORIA ${String(payload.Category || "B").toUpperCase()}`;

        body.classList.toggle("is-failed", !approved);
        body.classList.add("has-result");
        resultPanel.setAttribute("aria-hidden", "false");
        syncBodyVisibility();
    };

    const showChecklist = (payload) => {
        const state = payload && checklistStates[payload.State];
        if (!state) {
            hideChecklist();
            return;
        }

        hideResult();
        checklistGeneration += 1;
        const generation = checklistGeneration;
        const previousCompleted = checklistCompleted;
        checklistCompleted = state.completed;

        checklistStage.textContent = String(state.stage);
        checklistInstruction.textContent = state.instruction;
        checklistProgress.value = state.completed;
        checklistProgress.textContent = `${state.completed} de ${stepCopy.length}`;

        checklistSteps.forEach((step, index) => {
            const completed = index < state.completed;
            const current = state.completed < stepCopy.length && index === state.completed;
            const marker = step.querySelector(".checklist__marker");
            const label = step.querySelector(".checklist__label");

            step.classList.toggle("is-complete", completed);
            step.classList.toggle("is-current", current);
            step.classList.toggle("is-pending", !completed && !current);
            step.classList.remove("is-just-completed");
            marker.textContent = completed ? "✓" : (current ? "●" : "○");
            label.textContent = completed ? stepCopy[index].complete : stepCopy[index].pending;

            if (index >= previousCompleted && index < state.completed) {
                requestAnimationFrame(() => {
                    if (generation === checklistGeneration) {
                        step.classList.add("is-just-completed");
                    }
                });
            }
        });

        body.classList.add("has-checklist");
        checklistPanel.setAttribute("aria-hidden", "false");
        syncBodyVisibility();

        window.setTimeout(() => {
            if (generation === checklistGeneration) {
                checklistSteps.forEach((step) => step.classList.remove("is-just-completed"));
            }
        }, 900);
    };

    const hideAll = () => {
        hideChecklist();
        hideResult();
    };

    window.addEventListener("message", (event) => {
        const payload = event.data;
        if (!payload || typeof payload !== "object") {
            return;
        }

        if (payload.Action === "showResult") {
            showResult(payload);
        } else if (payload.Action === "hideResult") {
            hideResult();
        } else if (payload.Action === "showChecklist") {
            showChecklist(payload);
        } else if (payload.Action === "hideChecklist") {
            hideChecklist();
        }
    });

    window.addEventListener("error", hideAll);
    hideAll();
})();
