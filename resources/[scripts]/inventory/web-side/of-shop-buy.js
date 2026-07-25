(function () {
    "use strict";

    const buyButtonId = "of-shop-buy";
    const selectedClass = "of-shop-selected";
    const modal = {
        root: document.getElementById("shop-confirm-root"),
        item: document.getElementById("shop-confirm-item"),
        amount: document.getElementById("shop-confirm-amount"),
        unit: document.getElementById("shop-confirm-unit"),
        total: document.getElementById("shop-confirm-total"),
        message: document.getElementById("shop-confirm-message"),
        submit: document.getElementById("shop-confirm-submit"),
        cancel: document.getElementById("shop-confirm-cancel"),
        close: document.getElementById("shop-confirm-close")
    };

    let shopOpen = false;
    let shopItems = [];
    let selectedItem = null;
    let selectedCard = null;
    let activeQuote = null;
    let pending = false;
    let feedbackTimer = null;
    let layoutTimer = null;
    let lastAmountInput = null;
    let lastTypedAmount = 0;

    function post(resource, name, data) {
        return fetch(`https://${resource}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {})
        }).then(async (response) => {
            const body = await response.json().catch(() => null);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            return body;
        });
    }

    function normalize(text) {
        return String(text || "")
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, "");
    }

    function isVisible(element) {
        if (!element || !element.getBoundingClientRect) {
            return false;
        }

        const rect = element.getBoundingClientRect();
        return rect.width > 8 && rect.height > 8 && rect.bottom > 0 && rect.right > 0 && rect.top < window.innerHeight && rect.left < window.innerWidth;
    }

    function parseAmount(value) {
        const amount = Number.parseInt(String(value ?? "").trim(), 10);
        return Number.isFinite(amount) && amount > 0 ? amount : 0;
    }

    function isAmountInput(input) {
        if (!input || String(input.tagName || "").toLowerCase() !== "input") {
            return false;
        }

        const id = String(input.id || "").toLowerCase();
        const placeholder = normalize(input.getAttribute("placeholder"));
        const type = String(input.type || "").toLowerCase();
        return id === "remove-item" || placeholder.includes("quantidade") || placeholder.includes("amount") || (type === "number" && isVisible(input));
    }

    function findAmountInput() {
        if (lastAmountInput && document.contains(lastAmountInput) && isAmountInput(lastAmountInput) && isVisible(lastAmountInput)) {
            return lastAmountInput;
        }

        const direct = document.querySelector("#remove-item");
        if (direct && isVisible(direct)) {
            return direct;
        }

        return Array.from(document.querySelectorAll("input"))
            .filter((input) => isVisible(input) && isAmountInput(input))
            .sort((a, b) => b.getBoundingClientRect().bottom - a.getBoundingClientRect().bottom)[0] || null;
    }

    function readAmount() {
        if (lastTypedAmount > 0 && lastAmountInput && document.contains(lastAmountInput)) {
            return lastTypedAmount;
        }

        const input = findAmountInput();
        if (!input) {
            return 1;
        }

        for (const value of [input.valueAsNumber, input.value, input.getAttribute("value")]) {
            const amount = parseAmount(value);
            if (amount > 0) {
                return amount;
            }
        }

        return 1;
    }

    function isBuyShopPayload(payload) {
        if (!payload) {
            return false;
        }

        const isShop = payload.Type === "Shops" || payload.type === "Shops" || payload.Resource === "shops" || payload.resource === "shops";
        const mode = String(payload.Mode || payload.mode || "Buy").toLowerCase();
        const isFree = payload.Free === true || payload.free === true;
        return isShop && mode === "buy" && !isFree;
    }

    function normalizeItems(data) {
        const secondary = data && (data.Secondary || data.secondary);
        const raw = secondary && (secondary.Data || secondary.data);
        if (!raw) {
            shopItems = [];
            return;
        }

        shopItems = Array.isArray(raw)
            ? raw.filter(Boolean)
            : Object.keys(raw).sort((a, b) => Number(a) - Number(b)).map((key) => raw[key]).filter(Boolean);
    }

    async function refreshShopItems() {
        if (!shopOpen) {
            return;
        }

        try {
            normalizeItems(await post("shops", "Mount", {}));
            scheduleLayout();
        } catch (error) {
            shopItems = [];
        }
    }

    function findItemCard(element) {
        let node = element;
        for (let depth = 0; node && depth < 8; depth += 1) {
            const className = String(node.className || "");
            if (className.includes("aspect-square") && className.includes("rounded")) {
                return node;
            }
            node = node.parentElement;
        }
        return null;
    }

    function secondaryCards() {
        const amountInput = findAmountInput();
        const amountTop = amountInput ? amountInput.getBoundingClientRect().top : window.innerHeight;
        return Array.from(document.querySelectorAll(".aspect-square"))
            .filter((card) => String(card.className || "").includes("rounded") && isVisible(card))
            .filter((card) => {
                const rect = card.getBoundingClientRect();
                return rect.top > 90 && rect.top < amountTop - 8 && rect.left + rect.width / 2 > window.innerWidth * 0.52;
            })
            .sort((a, b) => {
                const ar = a.getBoundingClientRect();
                const br = b.getBoundingClientRect();
                return (ar.top - br.top) || (ar.left - br.left);
            });
    }

    function detectShopByDom() {
        const text = normalize(document.body && document.body.innerText);
        const hasShopText = ["loja", "mercearia", "shops", "farmacia", "lanchonete", "eletronicos"]
            .some((label) => text.includes(label));
        return hasShopText && !!findAmountInput() && secondaryCards().length > 0;
    }

    function clearSelection() {
        if (selectedCard && selectedCard.classList) {
            selectedCard.classList.remove(selectedClass);
        }
        selectedItem = null;
        selectedCard = null;
    }

    function selectFromTarget(target) {
        if (!shopOpen || isModalOpen()) {
            return;
        }

        const card = findItemCard(target);
        if (!card) {
            return;
        }

        const index = secondaryCards().indexOf(card);
        if (index < 0 || !shopItems[index]) {
            refreshShopItems();
            return;
        }

        clearSelection();
        selectedCard = card;
        selectedItem = shopItems[index].key || shopItems[index].Item || shopItems[index].item || null;
        selectedCard.classList.add(selectedClass);
        setButtonFeedback("Comprar", false, true);
    }

    function setButtonFeedback(message, danger, keep) {
        const button = document.getElementById(buyButtonId);
        if (!button) {
            return;
        }

        button.textContent = message;
        button.classList.toggle("of-shop-error", !!danger);
        clearTimeout(feedbackTimer);
        if (!keep) {
            feedbackTimer = setTimeout(() => {
                if (document.contains(button)) {
                    button.textContent = "Comprar";
                    button.classList.remove("of-shop-error");
                }
            }, 1800);
        }
    }

    function formatValue(value, currency) {
        const formatted = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 }).format(Number(value) || 0);
        if (currency === "R$") {
            return `R$ ${formatted}`;
        }
        if (currency === "Gratuito") {
            return "Gratuito";
        }
        return currency ? `${formatted} ${currency}` : formatted;
    }

    function isModalOpen() {
        return !!(modal.root && !modal.root.hidden);
    }

    function notifyDiagnostic(lastResponse) {
        post("shops", "ShopDiagnosticState", {
            ModalOpen: isModalOpen(),
            Pending: pending,
            LastResponse: lastResponse || "idle"
        }).catch(() => {});
    }

    function setModalMessage(message, type) {
        modal.message.textContent = message || "";
        modal.message.classList.toggle("is-error", type === "error");
        modal.message.classList.toggle("is-success", type === "success");
    }

    function setLoading(active) {
        pending = !!active;
        modal.submit.disabled = pending;
        modal.cancel.disabled = pending;
        modal.close.disabled = pending;
        modal.submit.textContent = pending ? "Processando..." : "Confirmar compra";
        notifyDiagnostic(pending ? "pending" : "ready");
    }

    function showQuote(quote) {
        activeQuote = quote;
        modal.item.textContent = quote.itemName || quote.item || "Produto";
        modal.amount.textContent = String(quote.amount || 1);
        modal.unit.textContent = formatValue(quote.unitPrice, quote.currency);
        modal.total.textContent = formatValue(quote.total, quote.currency);
        setModalMessage(quote.message || "Confira os dados do pedido.");
        modal.root.hidden = false;
        modal.root.setAttribute("aria-hidden", "false");
        modal.submit.focus();
        notifyDiagnostic("quote_created");
    }

    function hideModal() {
        activeQuote = null;
        pending = false;
        if (modal.root) {
            modal.root.hidden = true;
            modal.root.setAttribute("aria-hidden", "true");
        }
        modal.submit.disabled = false;
        modal.cancel.disabled = false;
        modal.close.disabled = false;
        modal.submit.textContent = "Confirmar compra";
        setModalMessage("");
        notifyDiagnostic("closed");
    }

    async function cancelQuote() {
        if (pending) {
            return;
        }

        const token = activeQuote && activeQuote.token;
        hideModal();
        if (token) {
            await post("shops", "CancelQuote", { Token: token }).catch(() => null);
        }
    }

    async function confirmQuote() {
        if (pending || !activeQuote || !activeQuote.token) {
            return;
        }

        setLoading(true);
        setModalMessage("Validando pedido...");
        try {
            const response = await post("shops", "ConfirmQuote", { Token: activeQuote.token });
            if (!response || response.success !== true) {
                setModalMessage(response && response.message || "Nao foi possivel concluir a compra.", "error");
                notifyDiagnostic(response && response.code || "rejected");
                return;
            }

            setModalMessage(response.message || "Compra realizada com sucesso.", "success");
            setButtonFeedback("Comprado", false);
            await new Promise((resolve) => setTimeout(resolve, 450));
            hideModal();
            setTimeout(refreshShopItems, 100);
        } catch (error) {
            setModalMessage("Falha de comunicacao com a loja. Tente novamente.", "error");
            notifyDiagnostic("fetch_error");
        } finally {
            if (isModalOpen()) {
                setLoading(false);
            }
        }
    }

    async function buySelected(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }

        if (pending || isModalOpen()) {
            return;
        }
        if (!shopOpen || !selectedItem) {
            setButtonFeedback("Selecione um item", true);
            return;
        }

        setButtonFeedback("Consultando...", false, true);
        try {
            const response = await post("shops", "CreateQuote", { Item: selectedItem, Amount: readAmount() });
            if (!response || response.success !== true) {
                setButtonFeedback(response && response.message || "Pedido recusado", true);
                notifyDiagnostic(response && response.code || "quote_rejected");
                return;
            }
            showQuote(response);
            setButtonFeedback("Comprar", false, true);
        } catch (error) {
            setButtonFeedback("Falha na loja", true);
            notifyDiagnostic("fetch_error");
        }
    }

    function addButtonStyle() {
        if (document.getElementById("of-shop-buy-style")) {
            return;
        }
        const style = document.createElement("style");
        style.id = "of-shop-buy-style";
        style.textContent = [
            `.${selectedClass}{box-shadow:0 0 0 .125rem rgba(214,169,78,.95),0 0 1.4rem rgba(214,169,78,.3)!important;}`,
            `#${buyButtonId}{position:fixed!important;z-index:8500!important;display:flex;align-items:center;justify-content:center;min-height:3.75rem;min-width:11.875rem;padding:0 1.25rem;border-radius:.45rem;border:.0625rem solid rgba(255,255,255,.22)!important;background:rgba(18,18,20,.98)!important;color:rgba(255,255,255,.92)!important;opacity:1!important;visibility:visible!important;pointer-events:auto!important;font:inherit;font-weight:800;text-transform:uppercase;letter-spacing:.02em;cursor:pointer;box-sizing:border-box;box-shadow:0 .3rem 1rem rgba(0,0,0,.28);}`,
            `#${buyButtonId}:hover{background:rgba(42,42,46,.98)!important;border-color:rgba(255,255,255,.5)!important;color:#fff!important;}`,
            `#${buyButtonId}.of-shop-error{background:rgba(100,42,35,.98)!important;border-color:rgba(255,110,100,.9)!important;color:#fff!important;}`
        ].join("");
        document.head.appendChild(style);
    }

    function placeButton(button) {
        const amountInput = findAmountInput();
        if (!amountInput) {
            return false;
        }
        if (button.parentElement !== document.body) {
            document.body.appendChild(button);
        }

        const rect = amountInput.getBoundingClientRect();
        const width = Math.max(rect.width, 190);
        const height = Math.max(rect.height, 60);
        let left = rect.right + 8;
        if (left + width > window.innerWidth - 16) {
            left = rect.left - width - 8;
        }
        button.style.left = `${Math.max(16, Math.round(left))}px`;
        button.style.top = `${Math.max(16, Math.round(rect.top))}px`;
        button.style.width = `${Math.round(width)}px`;
        button.style.height = `${Math.round(height)}px`;
        return true;
    }

    function ensureButton() {
        if (!shopOpen) {
            removeButton();
            return;
        }

        addButtonStyle();
        let button = document.getElementById(buyButtonId);
        if (!button) {
            button = document.createElement("button");
            button.id = buyButtonId;
            button.type = "button";
            button.textContent = "Comprar";
            button.addEventListener("click", buySelected, true);
        }
        if (!placeButton(button)) {
            removeButton();
        }
    }

    function removeButton() {
        clearTimeout(layoutTimer);
        clearTimeout(feedbackTimer);
        const button = document.getElementById(buyButtonId);
        if (button) {
            button.remove();
        }
    }

    function scheduleLayout() {
        clearTimeout(layoutTimer);
        layoutTimer = setTimeout(ensureButton, 30);
    }

    function setShopOpen(open) {
        shopOpen = !!open;
        if (shopOpen) {
            clearSelection();
            lastAmountInput = null;
            lastTypedAmount = 0;
            setTimeout(refreshShopItems, 250);
            setTimeout(ensureButton, 150);
            setTimeout(ensureButton, 700);
        } else {
            if (isModalOpen()) {
                cancelQuote();
            }
            clearSelection();
            shopItems = [];
            lastAmountInput = null;
            lastTypedAmount = 0;
            removeButton();
        }
    }

    function syncShopByDom() {
        const detected = detectShopByDom();
        if (detected && !shopOpen) {
            setShopOpen(true);
        } else if (!detected && shopOpen && !isModalOpen()) {
            setShopOpen(false);
        }
    }

    modal.submit.addEventListener("click", confirmQuote);
    modal.cancel.addEventListener("click", cancelQuote);
    modal.close.addEventListener("click", cancelQuote);
    document.addEventListener("pointerdown", (event) => selectFromTarget(event.target), true);
    document.addEventListener("input", (event) => {
        if (isAmountInput(event.target)) {
            lastAmountInput = event.target;
            lastTypedAmount = parseAmount(event.target.value);
        }
    }, true);
    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && isModalOpen()) {
            event.preventDefault();
            event.stopImmediatePropagation();
            cancelQuote();
        }
    }, true);
    window.addEventListener("resize", scheduleLayout);
    window.addEventListener("message", (event) => {
        const data = event.data || {};
        const payload = data.Payload || data.payload || {};
        if (data.Action === "Open") {
            setShopOpen(isBuyShopPayload(payload));
        } else if (data.Action === "Close") {
            setShopOpen(false);
        } else if (data.Action === "Backpack" && shopOpen) {
            setTimeout(refreshShopItems, 80);
        }
    });

    const observer = new MutationObserver(() => {
        syncShopByDom();
        if (shopOpen) {
            scheduleLayout();
        }
    });
    observer.observe(document.body, { childList: true, subtree: true, attributes: true });
    setInterval(syncShopByDom, 1200);
    setTimeout(syncShopByDom, 700);
})();
