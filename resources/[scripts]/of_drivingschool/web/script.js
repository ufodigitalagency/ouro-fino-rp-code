(() => {
    "use strict";

    const body = document.body;
    const resultPanel = document.querySelector(".result");
    const resultTitle = document.querySelector(".result__title");
    const resultReason = document.querySelector(".result__reason");
    const resultCategory = document.querySelector(".result__category");
    const resultReward = document.querySelector(".result__reward");
    const checklistPanel = document.querySelector(".checklist");
    const checklistStage = document.querySelector(".checklist__stage span");
    const checklistInstruction = document.querySelector(".checklist__instruction");
    const checklistProgress = document.querySelector(".checklist__progress");
    const checklistSteps = Array.from(document.querySelectorAll(".checklist__step"));
    const guidancePanel = document.querySelector(".guidance");
    const guidanceTitle = document.querySelector(".guidance__title");
    const guidanceInstruction = document.querySelector(".guidance__instruction");
    const guidanceDetail = document.querySelector(".guidance__detail");
    const guidanceHold = document.querySelector(".guidance__hold");
    const guidanceRoute = document.querySelector(".guidance__route span");
    const guidancePoints = document.querySelector(".guidance__points");
    const guidanceTest = document.querySelector(".guidance__test");

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
        body.classList.toggle("is-visible", body.classList.contains("has-result") || body.classList.contains("has-checklist") || body.classList.contains("has-guidance"));
    };

    const hideResult = () => {
        body.classList.remove("has-result", "is-failed");
        resultReward.hidden = true;
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

    const hideGuidance = () => {
        body.classList.remove("has-guidance");
        guidancePanel.classList.remove("is-warning", "is-danger", "is-success");
        guidancePanel.setAttribute("aria-hidden", "true");
        guidanceHold.hidden = true;
        guidanceDetail.hidden = true;
        syncBodyVisibility();
    };

    const renderPoints = (remaining, maximum) => {
        guidancePoints.replaceChildren();
        guidancePoints.append("Pontos ");
        for (let index = 0; index < maximum; index += 1) {
            const point = document.createElement("span");
            point.classList.toggle("is-active", index < remaining);
            point.textContent = "●";
            point.setAttribute("aria-hidden", "true");
            guidancePoints.append(point);
            if (index < maximum - 1) {
                guidancePoints.append(" ");
            }
        }
        guidancePoints.title = `${remaining} de ${maximum} pontos restantes`;
    };

    const showGuidance = (payload) => {
        if (!payload || typeof payload.Title !== "string") {
            hideGuidance();
            return;
        }

        hideChecklist();
        hideResult();
        const severity = ["warning", "danger", "success"].includes(payload.Severity) ? payload.Severity : "normal";
        const routeIndex = Math.max(0, Number(payload.RouteIndex) || 0);
        const routeTotal = Math.max(0, Number(payload.RouteTotal) || 0);
        const maximumPoints = Math.max(1, Math.floor(Number(payload.MaximumPoints) || 3));
        const remainingPoints = Math.min(maximumPoints, Math.max(0, Math.floor(Number(payload.RemainingPoints) || 0)));
        const holdTargetMs = Math.max(0, Number(payload.HoldTargetMs) || 0);
        const holdMs = Math.min(holdTargetMs, Math.max(0, Number(payload.HoldMs) || 0));
        let detail = String(payload.Detail || "");

        guidancePanel.classList.toggle("is-warning", severity === "warning");
        guidancePanel.classList.toggle("is-danger", severity === "danger");
        guidancePanel.classList.toggle("is-success", severity === "success");
        guidanceTitle.textContent = payload.Title;
        guidanceInstruction.textContent = String(payload.Instruction || "");
        guidanceRoute.textContent = `${routeIndex} / ${routeTotal}`;
        guidanceTest.hidden = payload.TestMode !== true;
        renderPoints(remainingPoints, maximumPoints);

        if (holdTargetMs > 0) {
            guidanceHold.max = holdTargetMs;
            guidanceHold.value = holdMs;
            guidanceHold.textContent = `${holdMs} de ${holdTargetMs}`;
            guidanceHold.hidden = false;
            if (!detail && holdMs > 0) {
                detail = `${(holdMs / 1000).toFixed(1)} / ${(holdTargetMs / 1000).toFixed(1)} s`;
            }
        } else {
            guidanceHold.hidden = true;
        }

        guidanceDetail.textContent = detail;
        guidanceDetail.hidden = detail === "";
        body.classList.add("has-guidance");
        guidancePanel.setAttribute("aria-hidden", "false");
        syncBodyVisibility();
    };

    const showResult = (payload) => {
        if (!payload || (payload.Result !== "approved" && payload.Result !== "failed")) {
            hideResult();
            return;
        }

        hideChecklist();
        hideGuidance();
        const approved = payload.Result === "approved";
        resultTitle.textContent = approved ? "APROVADO" : "REPROVADO";
        resultReason.textContent = String(payload.Reason || (approved
            ? "Você foi aprovado na prova prática."
            : "A prova prática não foi concluída."));
        resultCategory.textContent = `CNH CATEGORIA ${String(payload.Category || "B").toUpperCase()}`;
        resultReward.hidden = !(approved && payload.RewardGranted === true);

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
        hideGuidance();
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
        hideGuidance();
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
        } else if (payload.Action === "showGuidance") {
            showGuidance(payload);
        } else if (payload.Action === "hideGuidance") {
            hideGuidance();
        }
    });

    window.addEventListener("error", hideAll);
    hideAll();
})();
