const panel = document.getElementById("panel");
const modalBackdrop = document.getElementById("modalBackdrop");
const confirmBackdrop = document.getElementById("confirmBackdrop");
const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "af_owner_panel";

let catalog = { items: [], weapons: [] };
let players = [];
let selectedPlayer = null;
let selectedItem = null;
let pendingConfirm = null;
let moneyGrantPending = null;
let moneyGrantTimeout = null;
let premiumOrders = [];
let jobHierarchies = [];

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data)
    });
}

function byId(id) {
    return document.getElementById(id);
}

function on(id, event, handler) {
    const element = byId(id);
    if (element) {
        element.addEventListener(event, handler);
    }
}

function normalize(text) {
    return String(text || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function safeNumber(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function money(value) {
    return `$ ${new Intl.NumberFormat("pt-BR").format(Math.max(0, safeNumber(value, 0)))}`;
}

function value(id) {
    const element = byId(id);
    return element ? element.value : "";
}

function numberValue(id, fallback = 0) {
    return safeNumber(value(id), fallback);
}

function checked(id) {
    const element = byId(id);
    return Boolean(element && element.checked);
}

function setField(id, nextValue) {
    const element = byId(id);
    if (element && nextValue !== undefined && nextValue !== null) element.value = nextValue;
}

function updateJobRanks() {
    const jobSelect = byId("jobName");
    const rankSelect = byId("jobLevel");
    if (!jobSelect || !rankSelect) return;

    const job = jobHierarchies.find(entry => entry.id === jobSelect.value);
    const previousLevel = rankSelect.value;
    rankSelect.replaceChildren();

    if (!job || !Array.isArray(job.ranks) || job.ranks.length === 0) {
        const option = document.createElement("option");
        option.value = "";
        option.textContent = "Hierarquia indisponível";
        rankSelect.append(option);
        rankSelect.disabled = true;
        return;
    }

    job.ranks.forEach(rank => {
        const option = document.createElement("option");
        option.value = String(rank.level);
        option.textContent = String(rank.label || `Nível ${rank.level}`);
        rankSelect.append(option);
    });

    rankSelect.disabled = false;
    if ([...rankSelect.options].some(option => option.value === previousLevel)) {
        rankSelect.value = previousLevel;
    }
}

function renderJobHierarchies(payload) {
    const jobSelect = byId("jobName");
    if (!jobSelect) return;

    const previousJob = jobSelect.value;
    jobHierarchies = Array.isArray(payload) ? payload : [];
    jobSelect.replaceChildren();

    jobHierarchies.forEach(job => {
        const option = document.createElement("option");
        option.value = String(job.id || "");
        option.textContent = String(job.label || job.id || "Cargo");
        jobSelect.append(option);
    });

    if ([...jobSelect.options].some(option => option.value === previousJob)) {
        jobSelect.value = previousJob;
    }

    jobSelect.disabled = jobHierarchies.length === 0;
    updateJobRanks();
}

function volumeValue() {
    return Math.max(0, Math.min(100, Math.round(numberValue("telaoVolume", 100))));
}

function updateVolumeLabel() {
    const label = byId("telaoVolumeLabel");
    if (label) {
        label.textContent = `${volumeValue()}%`;
    }
}

function telaoPayload(action, includeGeometry = false) {
    const payload = {
        action,
        url: value("telaoUrl")
    };

    if (includeGeometry) {
        Object.assign(payload, {
            x: numberValue("telaoX", 0),
            y: numberValue("telaoY", 0),
            z: numberValue("telaoZ", 0),
            heading: numberValue("telaoHeading", 0),
            width: numberValue("telaoWidth", 9.6),
            height: numberValue("telaoHeight", 5.4),
            flipX: checked("telaoFlipX"),
            flipY: checked("telaoFlipY"),
            crop: {
                x: numberValue("telaoCropX", 0.02),
                y: numberValue("telaoCropY", 0.09),
                w: numberValue("telaoCropW", 0.685),
                h: numberValue("telaoCropH", 0.67)
            }
        });
    }

    return payload;
}

function applyTelaoAudio() {
    return Promise.all([
        post("telao", { action: "setBaseVolume", baseVolume: volumeValue(), silent: true }),
        post("telao", { action: "setMaxAudioDistance", maxAudioDistance: numberValue("telaoRange", 55), silent: true }),
        post("telao", { action: "setInnerAudioRadius", innerAudioRadius: numberValue("telaoInnerRadius", 4), silent: true }),
        post("telao", { action: "setAudioFalloff", falloffExponent: numberValue("telaoFalloff", 1.6), silent: true }),
        post("telao", { action: "setAudioEnabled", audioEnabled: checked("telaoAudioEnabled"), silent: true }),
        post("telao", { action: "setOcclusion", occlusionEnabled: checked("telaoOcclusion") })
    ]);
}

function itemList() {
    return Array.isArray(catalog.items) ? catalog.items : [];
}

function itemLabel(item) {
    return `${item.name || item.code} (${item.code})`;
}

function selectedPassport() {
    return selectedPlayer ? safeNumber(selectedPlayer.passport, 0) : 0;
}

function hasSelectedPlayer(showAlert = true) {
    if (selectedPassport() > 0) {
        return true;
    }

    if (showAlert) {
        openConfirm({
            title: "Selecione um jogador",
            text: "Escolha um jogador na lista da esquerda antes de executar esta ação.",
            confirmText: "Entendi",
            danger: false,
            onConfirm: closeConfirm
        });
    }

    return false;
}

function closePanel() {
    panel.hidden = true;
    panel.classList.add("hidden");
    closeItemModal(false);
    closeConfirm(false);
    post("close").catch(() => {});
}

function setHidden(element, hidden) {
    if (!element) return;
    element.hidden = hidden;
    element.classList.toggle("hidden", hidden);
}

function refreshClock() {
    const now = new Date();
    const date = now.toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit", year: "numeric" });
    const time = now.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit", second: "2-digit" });

    const clockDate = byId("clockDate");
    const clockTime = byId("clockTime");
    if (clockDate) clockDate.textContent = `${date} ${time}`;
    if (clockTime) clockTime.textContent = "Central F9";
}

function updateSelectedCard() {
    const name = selectedPlayer ? selectedPlayer.name || "Jogador" : "Selecione um jogador";
    const passport = selectedPlayer ? selectedPlayer.passport || "—" : "—";
    const source = selectedPlayer ? selectedPlayer.source || "—" : "—";

    byId("selectedName").textContent = name;
    byId("selectedBadge").textContent = selectedPlayer ? `#${passport}` : "#—";
    byId("selectedPassport").textContent = passport;
    byId("selectedSource").textContent = source;
    byId("selectedStatus").textContent = selectedPlayer ? "Online" : "Aguardando";

    byId("economyCash").textContent = money(selectedPlayer?.cash || 0);
    byId("economyBank").textContent = money(selectedPlayer?.bank || 0);
    byId("economyTargetName").textContent = selectedPlayer ? name : "Selecione um jogador";
    byId("economyTargetPassport").textContent = passport;
    byId("economyTargetSource").textContent = source;

    const modalTarget = byId("modalTarget");
    if (modalTarget) {
        modalTarget.textContent = selectedPlayer ? `#${passport} • ${name}` : "Nenhum jogador selecionado";
    }
}

function setEconomyStatus(message = "", error = false) {
    const status = byId("economyStatus");
    if (!status) return;
    status.textContent = message;
    status.classList.toggle("is-visible", Boolean(message));
    status.classList.toggle("is-error", error);
}

function setEconomyLoading(loading) {
    const button = byId("grantMoney");
    if (!button) return;
    button.disabled = loading;
    button.textContent = loading ? "Processando..." : "Conceder dinheiro";
}

function operationId() {
    return `grant-${Date.now()}-${Math.random().toString(36).slice(2, 12)}`;
}

async function submitMoneyGrant() {
    if (moneyGrantPending || !hasSelectedPlayer()) return;

    const amount = numberValue("economyAmount", 0);
    const reason = value("economyReason").trim();
    const account = value("economyAccount");
    if (!Number.isInteger(amount) || amount < 1 || amount > 10000000) {
        setEconomyStatus("Informe um valor inteiro entre $ 1 e $ 10.000.000.", true);
        return;
    }
    if (reason.length < 4 || reason.length > 120) {
        setEconomyStatus("Informe um motivo entre 4 e 120 caracteres.", true);
        return;
    }

    moneyGrantPending = operationId();
    setEconomyLoading(true);
    setEconomyStatus("Validando a concessao no servidor...");

    try {
        await post("grantMoney", {
            operationId: moneyGrantPending,
            passport: selectedPassport(),
            account,
            amount,
            reason
        });
        if (moneyGrantPending) {
            moneyGrantTimeout = window.setTimeout(() => {
                moneyGrantPending = null;
                setEconomyLoading(false);
                setEconomyStatus("O servidor demorou para responder. Confira os logs antes de tentar novamente.", true);
            }, 12000);
        }
    } catch (error) {
        moneyGrantPending = null;
        setEconomyLoading(false);
        setEconomyStatus("Falha de comunicacao com o servidor.", true);
    }
}

function selectPlayer(passport) {
    const wanted = String(passport || "");
    selectedPlayer = players.find(player => String(player.passport || "") === wanted) || null;
    updateSelectedCard();
    renderPlayers();
}

function renderPlayers() {
    const list = byId("playersList");
    if (!list) return;

    const query = normalize(value("playerSearch"));
    const filtered = players.filter(player => {
        const name = normalize(player.name);
        const passport = normalize(player.passport);
        const source = normalize(player.source);
        return !query || name.includes(query) || passport.includes(query) || source.includes(query);
    });

    list.innerHTML = "";

    if (!filtered.length) {
        const empty = document.createElement("p");
        empty.className = "empty-state";
        empty.textContent = players.length ? "Nenhum jogador encontrado." : "Nenhum jogador online encontrado.";
        list.appendChild(empty);
        return;
    }

    for (const player of filtered) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "player-row";
        if (selectedPlayer && String(selectedPlayer.passport) === String(player.passport)) {
            button.classList.add("active");
        }

        button.innerHTML = `
            <span class="mini-badge">#${player.passport || "?"}</span>
            <strong>${player.name || "Jogador"}</strong>
            <small>source ${player.source || "?"}</small>
        `;
        button.addEventListener("click", () => selectPlayer(player.passport));
        list.appendChild(button);
    }
}

function renderServerState(payload) {
    if (!payload) return;
    if (payload.weather && byId("serverWeather")) byId("serverWeather").value = payload.weather;
    if (payload.hour !== undefined && byId("serverHour")) byId("serverHour").value = payload.hour;
    if (payload.minute !== undefined && byId("serverMinute")) byId("serverMinute").value = payload.minute;
    if (payload.telaoVolume !== undefined && byId("telaoVolume")) {
        byId("telaoVolume").value = payload.telaoVolume;
        updateVolumeLabel();
    }

    const telao = payload.telao;
    if (!telao || telao.available === false) {
        const status = byId("telaoStatus");
        if (status) {
            status.textContent = "Indisponível";
            status.classList.add("offline");
        }
        return;
    }

    setField("telaoUrl", telao.url || "");
    setField("telaoVolume", telao.baseVolume ?? telao.volume ?? 70);
    setField("telaoRange", telao.maxAudioDistance ?? telao.audioRange ?? 55);
    setField("telaoInnerRadius", telao.innerAudioRadius ?? 4);
    setField("telaoFalloff", telao.falloffExponent ?? 1.6);
    setField("telaoX", telao.x);
    setField("telaoY", telao.y);
    setField("telaoZ", telao.z);
    setField("telaoHeading", telao.heading);
    setField("telaoWidth", telao.width);
    setField("telaoHeight", telao.height);
    setField("telaoCropX", telao.crop && telao.crop.x);
    setField("telaoCropY", telao.crop && telao.crop.y);
    setField("telaoCropW", telao.crop && (telao.crop.w ?? telao.crop.width));
    setField("telaoCropH", telao.crop && (telao.crop.h ?? telao.crop.height));

    if (byId("telaoAudioEnabled")) byId("telaoAudioEnabled").checked = telao.audioEnabled !== false;
    if (byId("telaoOcclusion")) byId("telaoOcclusion").checked = telao.occlusionEnabled !== false;
    if (byId("telaoFlipX")) byId("telaoFlipX").checked = telao.flipX === true;
    if (byId("telaoFlipY")) byId("telaoFlipY").checked = telao.flipY === true;

    const status = byId("telaoStatus");
    if (status) {
        status.textContent = telao.enabled ? "No ar" : "Desligado";
        status.classList.toggle("offline", !telao.enabled);
    }

    const playbackNames = { playing: "Reproduzindo", paused: "Pausado", stopped: "Parado" };
    if (byId("telaoPlayback")) byId("telaoPlayback").textContent = playbackNames[telao.playbackState] || "Aguardando";
    if (byId("telaoVideoId")) byId("telaoVideoId").textContent = telao.url || "Nenhum";
    if (byId("telaoLastOperator")) byId("telaoLastOperator").textContent = telao.lastOperator ? `ID ${telao.lastOperator}` : "—";
    if (byId("telaoLastChanged")) {
        const timestamp = Number(telao.lastChangedAt) || 0;
        byId("telaoLastChanged").textContent = timestamp > 0
            ? `Última alteração: ${new Date(timestamp * 1000).toLocaleString("pt-BR")}`
            : "Nenhuma alteração registrada nesta sessão.";
    }
    updateVolumeLabel();
}

function setActiveTab(tab) {
    document.querySelectorAll(".tab").forEach(button => {
        button.classList.toggle("active", button.dataset.tab === tab);
    });

    document.querySelectorAll(".tab-page").forEach(page => {
        page.classList.toggle("active", page.id === `tab-${tab}`);
    });

    if (tab === "payments") {
        requestPremiumOrders();
    }
}

function premiumMoney(cents) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(Math.max(0, safeNumber(cents, 0)) / 100);
}

function premiumDate(timestamp) {
    const value = safeNumber(timestamp, 0);
    return value > 0 ? new Date(value * 1000).toLocaleString("pt-BR") : "—";
}

function premiumStatus(status) {
    return ({
        pending: "Aguardando jogador",
        awaiting_review: "Aguardando revisão",
        processing: "Processando",
        approved: "Aprovado",
        rejected: "Recusado",
        expired: "Expirado"
    })[status] || status || "Desconhecido";
}

function requestPremiumOrders() {
    post("premiumOrders", { status: value("premiumOrderFilter") || "awaiting_review" }).catch(() => {});
}

function reviewPremiumOrder(order, action) {
    const approve = action === "approve";
    openConfirm({
        title: approve ? "Aprovar pagamento" : "Recusar pagamento",
        text: approve
            ? `Confirme no banco antes de ativar ${order.planName} para ${order.playerName} (#${order.passport}) no valor de ${premiumMoney(order.amountCents)}.`
            : `Recusar o pedido ${order.orderId} de ${order.playerName}?`,
        confirmText: approve ? "Aprovar e ativar" : "Recusar pedido",
        danger: !approve,
        onConfirm: () => post("reviewPremiumOrder", {
            orderId: order.orderId,
            action,
            status: value("premiumOrderFilter") || "awaiting_review"
        }).catch(() => {})
    });
}

function renderPremiumOrders() {
    const list = byId("premiumOrdersList");
    if (!list) return;

    if (!premiumOrders.length) {
        list.innerHTML = '<p class="empty-state">Nenhum pagamento encontrado neste filtro.</p>';
        return;
    }

    list.innerHTML = premiumOrders.map(order => {
        const reviewable = order.status === "awaiting_review";
        const rejectable = order.status === "awaiting_review" || order.status === "pending";
        return `
            <article class="premium-order-row">
                <div class="premium-order-main">
                    <span class="premium-order-protocol">${escapeHtml(order.orderId)}</span>
                    <strong>${escapeHtml(order.playerName)} <small>#${escapeHtml(order.passport)}</small></strong>
                    <p>${escapeHtml(order.planName)} · ${premiumMoney(order.amountCents)} · criado em ${premiumDate(order.createdAt)}</p>
                    ${order.lastError ? `<em>${escapeHtml(order.lastError)}</em>` : ""}
                </div>
                <div class="premium-order-state">
                    <span data-status="${escapeHtml(order.status)}">${escapeHtml(premiumStatus(order.status))}</span>
                    <small>Expira: ${premiumDate(order.expiresAt)}</small>
                </div>
                <div class="premium-order-actions">
                    ${reviewable ? '<button type="button" data-premium-approve>Aprovar e ativar</button>' : ""}
                    ${rejectable ? '<button type="button" class="danger-button" data-premium-reject>Recusar</button>' : ""}
                </div>
            </article>`;
    }).join("");

    list.querySelectorAll(".premium-order-row").forEach((row, index) => {
        row.querySelector("[data-premium-approve]")?.addEventListener("click", () => reviewPremiumOrder(premiumOrders[index], "approve"));
        row.querySelector("[data-premium-reject]")?.addEventListener("click", () => reviewPremiumOrder(premiumOrders[index], "reject"));
    });
}

function renderItemResults() {
    const results = byId("itemResults");
    if (!results) return;

    const query = normalize(value("itemSearch"));
    const items = itemList().filter(item => {
        if (!query) return true;
        return normalize(item.name).includes(query) || normalize(item.code).includes(query) || normalize(item.type).includes(query);
    }).slice(0, 80);

    results.innerHTML = "";

    if (!itemList().length) {
        const empty = document.createElement("p");
        empty.className = "empty-state";
        empty.textContent = "A lista de itens ainda não carregou. Feche e abra a central novamente.";
        results.appendChild(empty);
        return;
    }

    if (!items.length) {
        const empty = document.createElement("p");
        empty.className = "empty-state";
        empty.textContent = "Nenhum item encontrado com esse filtro.";
        results.appendChild(empty);
        return;
    }

    for (const item of items) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "item-row";
        if (selectedItem && selectedItem.code === item.code) {
            button.classList.add("active");
        }

        button.innerHTML = `
            <span class="item-avatar">${String(item.name || item.code || "?").slice(0, 1).toUpperCase()}</span>
            <span><strong>${item.name || item.code}</strong><small>${item.code} • ${item.type || "Item"}</small></span>
        `;
        button.addEventListener("click", () => {
            selectedItem = item;
            updateSelectedItemText();
            renderItemResults();
        });
        results.appendChild(button);
    }
}

function updateSelectedItemText() {
    const element = byId("selectedItemText");
    if (element) {
        element.textContent = selectedItem ? itemLabel(selectedItem) : "Nenhum item selecionado";
    }
}

function openItemModal() {
    if (!hasSelectedPlayer()) return;

    selectedItem = null;
    updateSelectedItemText();
    byId("itemSearch").value = "";
    byId("catalogAmount").value = "1";
    updateSelectedCard();
    renderItemResults();
    setHidden(modalBackdrop, false);
    setTimeout(() => byId("itemSearch")?.focus(), 30);
}

function closeItemModal(sendFocus = true) {
    setHidden(modalBackdrop, true);
    selectedItem = null;
    updateSelectedItemText();
    if (sendFocus) {
        panel?.focus?.();
    }
}

function openConfirm(options) {
    pendingConfirm = options || null;
    byId("confirmTitle").textContent = options?.title || "Confirmar ação";
    byId("confirmText").textContent = options?.text || "Confirme a ação selecionada.";
    byId("confirmActionButton").textContent = options?.confirmText || "Confirmar";
    byId("confirmActionButton").classList.toggle("danger-button", options?.danger !== false);

    const label = byId("confirmLabel");
    const input = byId("confirmInput");
    const withInput = !!options?.input;
    setHidden(label, !withInput);
    setHidden(input, !withInput);
    if (withInput) {
        label.textContent = options.inputLabel || "Motivo";
        input.placeholder = options.inputPlaceholder || "Motivo";
        input.value = options.inputValue || "";
    }

    setHidden(confirmBackdrop, false);
    setTimeout(() => withInput ? input.focus() : byId("confirmActionButton")?.focus(), 30);
}

function closeConfirm(sendFocus = true) {
    setHidden(confirmBackdrop, true);
    pendingConfirm = null;
    if (sendFocus) panel?.focus?.();
}

function submitAdminAction(action, payload = {}) {
    post("adminAction", { action, passport: selectedPassport(), ...payload });
}

function handleSimpleAction(action) {
    if (!hasSelectedPlayer()) return;

    if (action === "tptome") {
        submitAdminAction("tptome");
        return;
    }

    if (action === "ban") {
        openConfirm({
            title: "Banir jogador",
            text: `Deseja banir permanentemente o ID ${selectedPassport()}?`,
            confirmText: "Banir jogador",
            input: true,
            inputLabel: "Motivo do banimento",
            inputPlaceholder: "Ex: abuso, antirrp, trapaça...",
            inputValue: "Banimento administrativo",
            onConfirm: value => submitAdminAction("ban", { reason: value || "Banimento administrativo" })
        });
    }
}

window.addEventListener("message", event => {
    const action = event.data && event.data.action;

    if (action === "open") {
        panel.hidden = false;
        panel.classList.remove("hidden");
        post("adminAction", { action: "playersList" }).catch(() => {});
    }

    if (action === "close") {
        panel.hidden = true;
        panel.classList.add("hidden");
        closeItemModal(false);
        closeConfirm(false);
    }

    if (action === "catalogMode") {
        panel.hidden = false;
        panel.classList.remove("hidden");
        setActiveTab("inventory");
        if (selectedPassport() > 0) {
            openItemModal();
        }
    }

    if (action === "catalog") {
        catalog = event.data.payload || { items: [], weapons: [] };
        renderItemResults();
    }

    if (action === "jobHierarchies") {
        renderJobHierarchies(event.data.payload);
    }

    if (action === "players") {
        const previousPassport = selectedPlayer && String(selectedPlayer.passport || "");
        players = Array.isArray(event.data.payload) ? event.data.payload : [];
        selectedPlayer = players.find(player => String(player.passport || "") === previousPassport) || players[0] || null;
        updateSelectedCard();
        renderPlayers();
    }

    if (action === "moneyGrantResult") {
        const payload = event.data.payload || {};
        if (moneyGrantPending && payload.operationId && payload.operationId !== moneyGrantPending) return;
        if (moneyGrantTimeout) window.clearTimeout(moneyGrantTimeout);
        moneyGrantTimeout = null;
        moneyGrantPending = null;
        setEconomyLoading(false);
        setEconomyStatus(payload.message || (payload.success ? "Concessao concluida." : "Nao foi possivel concluir a concessao."), payload.success !== true);
        if (payload.success && selectedPlayer && String(selectedPlayer.passport) === String(payload.passport)) {
            selectedPlayer.cash = safeNumber(payload.cash, selectedPlayer.cash || 0);
            selectedPlayer.bank = safeNumber(payload.bank, selectedPlayer.bank || 0);
            updateSelectedCard();
            byId("economyAmount").value = "";
            byId("economyReason").value = "";
        }
    }

    if (action === "serverState") {
        renderServerState(event.data.payload || {});
    }

    if (action === "premiumOrders") {
        premiumOrders = Array.isArray(event.data.payload?.orders) ? event.data.payload.orders : [];
        renderPremiumOrders();
    }
});

panel.hidden = true;
panel.classList.add("hidden");
refreshClock();
setInterval(refreshClock, 1000);

on("close", "click", closePanel);
on("playerSearch", "input", renderPlayers);
on("refreshPlayers", "click", () => post("adminAction", { action: "playersList" }));
on("jobName", "change", updateJobRanks);
on("premiumOrderFilter", "change", requestPremiumOrders);
on("refreshPremiumOrders", "click", requestPremiumOrders);
on("grantMoney", "click", () => {
    if (!hasSelectedPlayer()) return;
    const amount = numberValue("economyAmount", 0);
    const account = value("economyAccount") === "cash" ? "carteira" : "banco";
    const reason = value("economyReason").trim();
    if (!Number.isInteger(amount) || amount < 1 || amount > 10000000 || reason.length < 4) {
        submitMoneyGrant();
        return;
    }

    openConfirm({
        title: "Confirmar concessao",
        text: `Conceder ${money(amount)} no ${account} de ${selectedPlayer.name} (#${selectedPassport()})? Esta acao sera registrada.`,
        confirmText: "Confirmar concessao",
        danger: false,
        onConfirm: submitMoneyGrant
    });
});

on("openItemModal", "click", openItemModal);
on("closeItemModal", "click", () => closeItemModal());
on("cancelItemModal", "click", () => closeItemModal());
on("itemSearch", "input", renderItemResults);

on("giveCatalogItem", "click", () => {
    if (!hasSelectedPlayer()) return;
    if (!selectedItem) {
        openConfirm({
            title: "Selecione um item",
            text: "Escolha um item na lista antes de confirmar a entrega.",
            confirmText: "Entendi",
            danger: false,
            onConfirm: closeConfirm
        });
        return;
    }

    post("adminAction", {
        action: "giveItem",
        passport: selectedPassport(),
        item: selectedItem.code,
        amount: numberValue("catalogAmount", 1)
    });
    closeItemModal();
});

on("closeConfirmModal", "click", () => closeConfirm());
on("cancelConfirmModal", "click", () => closeConfirm());
on("confirmActionButton", "click", () => {
    if (pendingConfirm && typeof pendingConfirm.onConfirm === "function") {
        pendingConfirm.onConfirm(value("confirmInput"));
    }
    closeConfirm();
});

document.querySelectorAll(".tab").forEach(button => {
    button.addEventListener("click", () => setActiveTab(button.dataset.tab));
});

document.querySelectorAll("[data-client]").forEach(button => {
    button.addEventListener("click", () => {
        post("clientAction", { action: button.dataset.client });
    });
});

document.querySelectorAll("[data-action]").forEach(button => {
    button.addEventListener("click", () => handleSimpleAction(button.dataset.action));
});

on("setAdmin", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("setAdmin", { level: numberValue("adminLevel", 1) });
});

on("removeAdmin", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("removeAdmin");
});

on("setJob", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("setJob", { job: value("jobName"), level: numberValue("jobLevel", 1) });
});

on("removeJob", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("removeJob", { job: value("jobName") });
});

on("setPlan", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("setPlan", { plan: value("planName") });
});

on("removePlan", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("removePlan");
});

on("giveWeapon", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("giveWeapon", { item: value("weaponItem"), ammo: numberValue("weaponAmmo", 0) });
});

on("givePoliceKit", "click", () => {
    if (!hasSelectedPlayer()) return;
    submitAdminAction("givePoliceKit");
});

on("setWeather", "click", () => {
    post("adminAction", { action: "setWeather", weather: value("serverWeather") });
});

on("setTime", "click", () => {
    post("adminAction", { action: "setTime", hour: numberValue("serverHour", 12), minute: numberValue("serverMinute", 0) });
});

on("telaoOn", "click", () => post("telao", telaoPayload("on")));
on("telaoOff", "click", () => post("telao", { action: "off" }));
on("telaoUrlBtn", "click", () => post("telao", telaoPayload("url")));
on("telaoVolume", "input", updateVolumeLabel);
on("telaoPause", "click", () => post("telao", { action: "pause" }));
on("telaoResume", "click", () => post("telao", { action: "resume" }));
on("telaoReload", "click", () => post("telao", { action: "reload" }));
on("telaoSync", "click", () => post("telao", { action: "sync" }));
on("telaoApplyAudio", "click", () => applyTelaoAudio());
on("telaoTestAudio", "click", () => post("telao", { action: "testAudio" }));
on("telaoAudioStatus", "click", () => post("telao", { action: "audioStatus" }));
on("telaoApplyGeometry", "click", () => post("telao", telaoPayload("set", true)));
on("telaoHere", "click", () => post("telao", telaoPayload("here")));
on("telaoEdit", "click", () => post("telao", { action: "edit" }));
on("telaoCancelEdit", "click", () => post("telao", { action: "cancelEdit" }));
on("telaoSave", "click", () => post("telao", telaoPayload("save", true)));

updateVolumeLabel();

document.addEventListener("keydown", event => {
    if (event.key === "Escape") {
        if (!confirmBackdrop.hidden) return closeConfirm();
        if (!modalBackdrop.hidden) return closeItemModal();
        closePanel();
    }
});
