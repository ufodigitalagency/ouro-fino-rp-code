(() => {
    "use strict";

    const post = async (name, payload = {}) => {
        const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(payload)
        });
        return response.json();
    };

    const root = document.createElement("div");
    root.id = "ofcnh-admin";
    root.innerHTML = `
        <button type="button" class="ofcnh-launcher" aria-label="Gerenciar CNH">
            <span class="ofcnh-launcher__icon">CNH</span>
            <span>Gerenciar CNH</span>
        </button>
        <div class="ofcnh-backdrop" hidden>
            <section class="ofcnh-card" role="dialog" aria-modal="true" aria-label="Gerenciar CNH">
                <header class="ofcnh-header">
                    <div>
                        <span class="ofcnh-kicker">OURO FINO • ADMINISTRAÇÃO</span>
                        <h2>Gerenciar CNH</h2>
                    </div>
                    <button type="button" class="ofcnh-close" aria-label="Fechar">×</button>
                </header>

                <div class="ofcnh-grid">
                    <label>
                        <span>Passaporte</span>
                        <input class="ofcnh-passport" inputmode="numeric" autocomplete="off" placeholder="Ex.: 1">
                    </label>
                    <label>
                        <span>Categoria</span>
                        <select class="ofcnh-category">
                            <option value="A">Categoria A</option>
                            <option value="B" selected>Categoria B</option>
                            <option value="C">Categoria C</option>
                            <option value="D">Categoria D</option>
                        </select>
                    </label>
                </div>

                <label class="ofcnh-reason-wrap">
                    <span>Motivo / observação</span>
                    <input class="ofcnh-reason" maxlength="255" autocomplete="off"
                        placeholder="Obrigatório para remover uma CNH">
                </label>

                <div class="ofcnh-actions">
                    <button type="button" class="ofcnh-button ofcnh-button--ghost" data-action="lookup">Consultar</button>
                    <button type="button" class="ofcnh-button ofcnh-button--grant" data-action="grant">Dar / reativar</button>
                    <button type="button" class="ofcnh-button ofcnh-button--revoke" data-action="revoke">Remover</button>
                </div>

                <div class="ofcnh-result" aria-live="polite">
                    <p class="ofcnh-result__message">Informe um passaporte para consultar ou alterar a CNH.</p>
                    <div class="ofcnh-statuses"></div>
                </div>
            </section>
        </div>
    `;
    document.body.appendChild(root);

    const launcher = root.querySelector(".ofcnh-launcher");
    const backdrop = root.querySelector(".ofcnh-backdrop");
    const close = root.querySelector(".ofcnh-close");
    const passport = root.querySelector(".ofcnh-passport");
    const category = root.querySelector(".ofcnh-category");
    const reason = root.querySelector(".ofcnh-reason");
    const message = root.querySelector(".ofcnh-result__message");
    const statuses = root.querySelector(".ofcnh-statuses");
    const buttons = [...root.querySelectorAll("[data-action]")];

    let allowed = false;
    let busy = false;

    const setAllowed = (value) => {
        allowed = value === true;
        root.classList.toggle("is-allowed", allowed);
        if (!allowed) {
            backdrop.hidden = true;
        }
    };

    const setBusy = (value) => {
        busy = value === true;
        buttons.forEach((button) => button.disabled = busy);
    };

    const showMessage = (text, success = false) => {
        message.textContent = text || "";
        message.classList.toggle("is-success", success);
        message.classList.toggle("is-error", !success);
    };

    const renderLicenses = (data) => {
        statuses.replaceChildren();
        const found = new Map((data.licenses || []).map((license) => [
            String(license.Category || "").toUpperCase(),
            String(license.Status || "").toLowerCase()
        ]));

        ["A", "B", "C", "D"].forEach((letter) => {
            const status = found.get(letter) || "sem registro";
            const item = document.createElement("div");
            item.className = `ofcnh-status ofcnh-status--${status.replace(/[^a-z]/g, "")}`;
            const categoryLabel = document.createElement("strong");
            categoryLabel.textContent = `CNH ${letter}`;
            const statusLabel = document.createElement("span");
            statusLabel.textContent = status;
            item.append(categoryLabel, statusLabel);
            statuses.appendChild(item);
        });

        const name = data.name ? ` • ${data.name}` : "";
        showMessage(`Passaporte ${data.passport}${name}`, true);
    };

    const payload = (action) => ({
        Passport: Number(passport.value),
        Category: category.value,
        Action: action,
        Reason: reason.value
    });

    const lookup = async () => {
        if (!allowed || busy) return;
        const id = Number(passport.value);
        if (!Number.isInteger(id) || id <= 0) {
            showMessage("Informe um passaporte válido.");
            statuses.replaceChildren();
            return;
        }

        setBusy(true);
        try {
            const result = await post("OFCNHAdminLookup", { Passport: id });
            if (result && result.success) {
                renderLicenses(result);
            } else {
                statuses.replaceChildren();
                showMessage(result?.message || "Não foi possível consultar a CNH.");
            }
        } catch (_) {
            statuses.replaceChildren();
            showMessage("Falha de comunicação com o painel.");
        } finally {
            setBusy(false);
        }
    };

    const act = async (action) => {
        if (!allowed || busy) return;
        const id = Number(passport.value);
        if (!Number.isInteger(id) || id <= 0) {
            showMessage("Informe um passaporte válido.");
            return;
        }
        if (action === "revoke" && !reason.value.trim()) {
            showMessage("Informe o motivo antes de remover a CNH.");
            reason.focus();
            return;
        }

        setBusy(true);
        try {
            const result = await post("OFCNHAdminAction", payload(action));
            showMessage(result?.message || "Ação concluída.", result?.success === true);
            if (result?.success) {
                setBusy(false);
                await lookup();
                return;
            }
        } catch (_) {
            showMessage("Falha de comunicação com o painel.");
        } finally {
            setBusy(false);
        }
    };

    launcher.addEventListener("click", () => {
        if (!allowed) return;
        backdrop.hidden = false;
        setTimeout(() => passport.focus(), 0);
    });

    close.addEventListener("click", () => backdrop.hidden = true);
    backdrop.addEventListener("click", (event) => {
        if (event.target === backdrop) backdrop.hidden = true;
    });

    buttons.forEach((button) => {
        button.addEventListener("click", () => {
            const action = button.dataset.action;
            if (action === "lookup") lookup();
            else act(action);
        });
    });

    passport.addEventListener("keydown", (event) => {
        if (event.key === "Enter") lookup();
    });

    window.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && !backdrop.hidden) {
            event.stopPropagation();
            backdrop.hidden = true;
        }
    }, true);

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        if (data.Action === "OFCNHAdminVisibility") {
            setAllowed(data.Payload?.Visible === true);
        }
    });

    setAllowed(false);
})();