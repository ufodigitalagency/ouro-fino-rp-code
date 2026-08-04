(() => {
    "use strict";

    const state = {
        visible: false,
        waiting: false,
        loading: false,
        owner: "",
        items: [],
        total: 0,
        doors: {},
        vehicleState: {
            engine: false,
            lights: false
        }
    };

    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "lscustoms";
    let panel;
    let cart;
    let total;
    let owner;
    let status;
    let submit;
    let modal;
    let modalSummary;
    let modalTotal;

    const money = (value) => new Intl.NumberFormat("pt-BR").format(Number(value) || 0);

    async function nui(name, payload = {}) {
        const controller = new AbortController();
        const timeout = window.setTimeout(() => controller.abort(), 12000);
        try {
            const response = await fetch(`https://${resource}/${name}`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify(payload),
                signal: controller.signal
            });
            const text = await response.text();
            return text ? JSON.parse(text) : {};
        } finally {
            window.clearTimeout(timeout);
        }
    }

    function syncButtons() {
        document.querySelectorAll(".of-mechanic-panel button, .of-mechanic-modal button").forEach((button) => {
            button.disabled = state.loading || (state.waiting && !button.hasAttribute("data-waiting-allowed")) || (button === submit && state.items.length === 0);
        });
        if (submit) {
            submit.textContent = state.loading ? "PROCESSANDO..." : state.waiting ? "AGUARDANDO CLIENTE" : "ENVIAR ORCAMENTO";
        }
    }

    function setLoading(value) {
        state.loading = value;
        syncButtons();
    }

    function showStatus(message, error = false) {
        status.textContent = message || "";
        status.classList.toggle("is-visible", Boolean(message));
        status.classList.toggle("is-error", error);
    }

    function render() {
        if (!panel) return;
        panel.classList.toggle("is-visible", state.visible);
        document.body.classList.toggle("of-mechanic-open", state.visible);
        owner.textContent = state.owner ? `Cliente: ${state.owner}` : "Cliente nao identificado";
        total.textContent = `$ ${money(state.total)}`;
        submit.disabled = state.loading || state.waiting || state.items.length === 0;
        submit.textContent = state.waiting ? "AGUARDANDO CLIENTE" : "ENVIAR ORCAMENTO";
        syncButtons();
        panel.querySelectorAll("[data-door]").forEach((button) => {
            const door = Number(button.dataset.door);
            button.hidden = door >= 0 && state.doors[String(door)] !== true;
        });
        panel.querySelectorAll("[data-vehicle-control]").forEach((button) => {
            const control = button.dataset.vehicleControl;
            const active = state.vehicleState[control] === true;
            button.classList.toggle("is-active", active);
            if (control === "engine") {
                button.textContent = active ? "DESLIGAR MOTOR" : "LIGAR MOTOR";
            } else if (control === "lights") {
                button.textContent = active ? "DESLIGAR FAROIS" : "LIGAR FAROIS";
            }
        });

        if (!state.items.length) {
            cart.innerHTML = '<div class="of-mechanic-empty">As alteracoes selecionadas aparecem aqui antes de serem enviadas ao cliente.</div>';
            return;
        }

        cart.innerHTML = state.items.map((item) => `
            <article class="of-mechanic-item">
                <div class="of-mechanic-item-label">${escapeHtml(item.label)}</div>
                <div class="of-mechanic-item-detail">${escapeHtml(item.detail || "Alteracao selecionada")}</div>
                <div class="of-mechanic-item-price">$ ${money(item.price)}</div>
                <button class="of-mechanic-item-remove" data-remove="${escapeHtml(item.id)}" type="button">REMOVER DO ORCAMENTO</button>
            </article>
        `).join("");
    }

    function escapeHtml(value) {
        return String(value ?? "").replace(/[&<>'"]/g, (character) => ({
            "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
        })[character]);
    }

    async function action(name, payload = {}) {
        if (state.loading) return null;
        setLoading(true);
        showStatus("");
        try {
            const response = await nui(name, payload);
            if (response && response.success === false) {
                showStatus(response.message || "Nao foi possivel concluir a acao.", true);
            }
            return response;
        } catch (error) {
            console.error(`[lscustoms] ${name}:`, error);
            showStatus("Falha de comunicacao com a oficina.", true);
            return null;
        } finally {
            setLoading(false);
        }
    }

    function createUi() {
        panel = document.createElement("aside");
        panel.className = "of-mechanic-panel";
        panel.innerHTML = `
            <header class="of-mechanic-header">
                <div class="of-mechanic-eyebrow">Bennys Motor Works</div>
                <h1 class="of-mechanic-title">Orcamento</h1>
                <div class="of-mechanic-owner"></div>
            </header>
            <div class="of-mechanic-status"></div>
            <section class="of-mechanic-section">
                <div class="of-mechanic-section-title">Acesso ao veiculo</div>
                <div class="of-mechanic-doors">
                    <button class="of-mechanic-door" data-door="4" type="button">CAPO</button>
                    <button class="of-mechanic-door" data-door="5" type="button">PORTA-MALAS</button>
                    <button class="of-mechanic-door" data-door="-1" type="button">FECHAR</button>
                    <button class="of-mechanic-door" data-door="0" type="button">D. ESQ.</button>
                    <button class="of-mechanic-door" data-door="1" type="button">D. DIR.</button>
                    <button class="of-mechanic-door" data-door="2" type="button">T. ESQ.</button>
                    <button class="of-mechanic-door" data-door="3" type="button">T. DIR.</button>
                </div>
                <div class="of-mechanic-section-title of-mechanic-section-title-controls">Sistemas</div>
                <div class="of-mechanic-controls">
                    <button class="of-mechanic-control" data-vehicle-control="engine" type="button">LIGAR MOTOR</button>
                    <button class="of-mechanic-control" data-vehicle-control="lights" type="button">LIGAR FAROIS</button>
                </div>
            </section>
            <section class="of-mechanic-cart"></section>
            <footer class="of-mechanic-footer">
                <div class="of-mechanic-total"><span>Total</span><strong>$ 0</strong></div>
                <div class="of-mechanic-actions">
                    <button class="of-mechanic-secondary" data-restore type="button">RESTAURAR</button>
                    <button class="of-mechanic-danger" data-cancel type="button">CANCELAR</button>
                    <button class="of-mechanic-primary" data-submit type="button">ENVIAR ORCAMENTO</button>
                </div>
            </footer>
        `;
        document.body.appendChild(panel);

        modal = document.createElement("div");
        modal.className = "of-mechanic-modal";
        modal.innerHTML = `
            <div class="of-mechanic-modal-card">
                <div class="of-mechanic-eyebrow">Confirmacao interna</div>
                <h2>Confirmar orcamento?</h2>
                <p class="of-mechanic-modal-summary"></p>
                <div class="of-mechanic-modal-total"></div>
                <div class="of-mechanic-modal-actions">
                    <button class="of-mechanic-modal-button" data-self-reject data-waiting-allowed type="button">CANCELAR</button>
                    <button class="of-mechanic-modal-button is-confirm" data-self-confirm data-waiting-allowed type="button">CONFIRMAR</button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        cart = panel.querySelector(".of-mechanic-cart");
        total = panel.querySelector(".of-mechanic-total strong");
        owner = panel.querySelector(".of-mechanic-owner");
        status = panel.querySelector(".of-mechanic-status");
        submit = panel.querySelector("[data-submit]");
        modalSummary = modal.querySelector(".of-mechanic-modal-summary");
        modalTotal = modal.querySelector(".of-mechanic-modal-total");

        panel.addEventListener("click", async (event) => {
            const remove = event.target.closest("[data-remove]");
            const door = event.target.closest("[data-door]");
            const vehicleControl = event.target.closest("[data-vehicle-control]");
            if (remove) await action("RemoveCartItem", { id: remove.dataset.remove });
            if (door) await action("VehicleDoor", { door: Number(door.dataset.door) });
            if (vehicleControl) {
                const response = await action("VehicleControl", { action: vehicleControl.dataset.vehicleControl });
                if (response && response.success) {
                    state.vehicleState[vehicleControl.dataset.vehicleControl] = response.active === true;
                    showStatus(response.message || "");
                    render();
                }
            }
            if (event.target.closest("[data-restore]")) await action("RestorePreview");
            if (event.target.closest("[data-cancel]")) await action("CancelService");
            if (event.target.closest("[data-submit]")) {
                const response = await action("SubmitQuote");
                if (response && response.success) {
                    state.waiting = true;
                    showStatus(response.message || "Orcamento enviado.");
                    render();
                }
            }
        });

        modal.addEventListener("click", async (event) => {
            const accepted = Boolean(event.target.closest("[data-self-confirm]"));
            if (!accepted && !event.target.closest("[data-self-reject]")) return;
            const response = await action("ConfirmSelfQuote", { accepted });
            if (response && response.success) {
                modal.classList.remove("is-visible");
                if (!accepted) state.waiting = false;
            }
        });
    }

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        const payload = data.Payload || {};
        if (data.Action === "Open") {
            state.visible = true;
            state.waiting = false;
            state.owner = "";
            state.items = [];
            state.total = 0;
            state.doors = {};
            state.vehicleState = { engine: false, lights: false };
            showStatus("");
            render();
        } else if (data.Action === "Close") {
            state.visible = false;
            state.waiting = false;
            state.items = [];
            state.total = 0;
            state.doors = {};
            state.vehicleState = { engine: false, lights: false };
            modal.classList.remove("is-visible");
            render();
        } else if (data.Action === "MechanicCart") {
            state.items = Array.isArray(payload.items) ? payload.items : [];
            state.total = Number(payload.total) || 0;
            state.owner = payload.owner || state.owner;
            state.waiting = payload.waiting === true;
            state.doors = payload.doors && typeof payload.doors === "object" ? payload.doors : {};
            state.vehicleState = payload.vehicleState && typeof payload.vehicleState === "object"
                ? {
                    engine: payload.vehicleState.engine === true,
                    lights: payload.vehicleState.lights === true
                }
                : { engine: false, lights: false };
            render();
        } else if (data.Action === "MechanicState") {
            state.waiting = payload.state === "waiting";
            if (payload.state === "closed") state.visible = false;
            showStatus(payload.message || "", payload.state === "error");
            render();
        } else if (data.Action === "MechanicSelfConfirm") {
            modalSummary.textContent = `${payload.vehicle || "Veiculo"}: ${payload.summary || "alteracoes selecionadas"}`;
            modalTotal.textContent = `$ ${money(payload.total)}`;
            modal.classList.add("is-visible");
        }
    });

    document.addEventListener("DOMContentLoaded", createUi);
})();
