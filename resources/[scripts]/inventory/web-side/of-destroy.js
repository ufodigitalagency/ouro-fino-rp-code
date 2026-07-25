(function () {
    "use strict";

    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "inventory";
    const buttonId = "of-inventory-destroy";
    const selectedClass = "of-destroy-selected";

    let inventoryOpen = false;
    let lastSlot = null;
    let lastCard = null;
    let feedbackTimer = null;
    let destroying = false;
    let observer = null;
    let pointerX = 0;
    let pointerY = 0;
    let draggingItem = false;
    let lastDropAt = 0;
    let primarySlots = {};
    let dragStartX = 0;
    let dragStartY = 0;
    let clearingDrag = false;

    function post(name, data) {
        return fetch(`https://${resource}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {})
        }).then((response) => response.json().catch(() => response.text()).catch(() => false));
    }

    function isNumericSlot(value) {
        const text = String(value == null ? "" : value).trim();
        if (!/^\d{1,3}$/.test(text)) {
            return false;
        }

        const number = Number(text);
        return number > 0 && number < 500;
    }

    function normalizeSlot(value) {
        return isNumericSlot(value) ? String(Number(value)) : null;
    }

    function readFromObject(object) {
        if (!object || typeof object !== "object") {
            return null;
        }

        for (const key of ["Slot", "slot", "Index", "index", "Number", "number"]) {
            const slot = normalizeSlot(object[key]);
            if (slot) {
                return slot;
            }
        }

        for (const key of ["Item", "item", "Data", "data"]) {
            const nested = object[key];
            if (nested && typeof nested === "object") {
                const slot = readFromObject(nested);
                if (slot) {
                    return slot;
                }
            }
        }

        return null;
    }

    function readVueSlot(element) {
        let node = element;
        let nodeDepth = 0;

        while (node && nodeDepth < 8) {
            let component = node.__vueParentComponent || (node.__vnode && node.__vnode.component);
            let componentDepth = 0;

            while (component && componentDepth < 10) {
                for (const pack of [component.props, component.attrs, component.setupState, component.ctx]) {
                    const slot = readFromObject(pack);
                    if (slot) {
                        return slot;
                    }
                }

                component = component.parent;
                componentDepth += 1;
            }

            node = node.parentElement;
            nodeDepth += 1;
        }

        return null;
    }

    function readTextSlot(element) {
        let node = element;
        let depth = 0;

        while (node && depth < 6) {
            const candidates = Array.from(node.querySelectorAll ? node.querySelectorAll("*") : []);
            const ranked = [];

            for (const child of candidates) {
                const text = (child.textContent || "").trim();
                const slot = normalizeSlot(text);
                if (!slot) {
                    continue;
                }

                const className = String(child.className || "");
                const score = (className.includes("bottom") ? 3 : 0) +
                    (className.includes("right") ? 3 : 0) +
                    (className.includes("absolute") ? 2 : 0) +
                    (className.includes("text-xs") ? 1 : 0);

                ranked.push({ slot, score });
            }

            ranked.sort((a, b) => b.score - a.score);
            if (ranked.length > 0) {
                return ranked[0].slot;
            }

            node = node.parentElement;
            depth += 1;
        }

        return null;
    }

    function findSlot(element) {
        if (!element) {
            return null;
        }

        const dataSlot = normalizeSlot(element.dataset && (element.dataset.slot || element.dataset.index || element.dataset.id));
        if (dataSlot) {
            return dataSlot;
        }

        return readVueSlot(element) || readVisualSlot(element) || readTextSlot(element);
    }

    function findSlotAtPoint(x, y) {
        if (!document.elementsFromPoint || !Number.isFinite(x) || !Number.isFinite(y)) {
            return null;
        }

        for (const element of document.elementsFromPoint(x, y)) {
            if (!element || element.closest(`#${buttonId}`)) {
                continue;
            }

            const slot = findSlot(element);
            if (slot) {
                return slot;
            }
        }

        return null;
    }

    function findItemCard(element) {
        let node = element;
        let depth = 0;

        while (node && depth < 8) {
            const className = String(node.className || "");
            if (className.includes("aspect-square") && className.includes("rounded")) {
                return node;
            }

            node = node.parentElement;
            depth += 1;
        }

        return element && element.nodeType === 1 ? element : null;
    }

    function isVisibleCard(element) {
        if (!element || !element.getBoundingClientRect) {
            return false;
        }

        const rect = element.getBoundingClientRect();
        return rect.width >= 40 &&
            rect.height >= 40 &&
            rect.bottom > 0 &&
            rect.right > 0 &&
            rect.top < window.innerHeight &&
            rect.left < window.innerWidth;
    }

    function readVisualSlot(element) {
        const targetCard = findItemCard(element);
        if (!targetCard || !isVisibleCard(targetCard)) {
            return null;
        }

        const actionButton = findActionButton("Usar item") || findActionButton("Enviar item") || getDestroyButton();
        const actionTop = actionButton ? actionButton.getBoundingClientRect().top : window.innerHeight;
        const proximityLabel = findTextElement("Proximidade");
        const proximityLeft = proximityLabel ? proximityLabel.getBoundingClientRect().left : (window.innerWidth * 0.53);

        const cards = Array.from(document.querySelectorAll(".aspect-square"))
            .filter((card) => String(card.className || "").includes("rounded"))
            .filter(isVisibleCard)
            .filter((card) => {
                const rect = card.getBoundingClientRect();
                const centerX = rect.left + (rect.width / 2);

                return rect.top > 90 &&
                    rect.top < actionTop - 8 &&
                    centerX < proximityLeft - 12;
            });

        if (!cards.includes(targetCard)) {
            return null;
        }

        const rects = cards.map((card) => ({ card, rect: card.getBoundingClientRect() }));
        const minLeft = Math.min(...rects.map((entry) => entry.rect.left));
        const averageWidth = rects.reduce((total, entry) => total + entry.rect.width, 0) / rects.length;
        const leftClusters = [];

        for (const entry of rects.sort((a, b) => a.rect.left - b.rect.left)) {
            if (!leftClusters.some((left) => Math.abs(left - entry.rect.left) < averageWidth * 0.35)) {
                leftClusters.push(entry.rect.left);
            }
        }

        leftClusters.sort((a, b) => a - b);

        const hotbarLimit = leftClusters.length > 1 ?
            ((leftClusters[0] + leftClusters[1]) / 2) :
            (minLeft + (averageWidth * 1.2));
        const hotbar = rects
            .filter((entry) => entry.rect.left <= hotbarLimit)
            .sort((a, b) => a.rect.top - b.rect.top);

        const hotbarIndex = hotbar.findIndex((entry) => entry.card === targetCard);
        if (hotbarIndex >= 0) {
            const slot = normalizeSlot(hotbarIndex + 1);
            return slot && (primarySlots[slot] || hotbarIndex < 4) ? slot : null;
        }

        const grid = rects
            .filter((entry) => entry.rect.left > hotbarLimit)
            .sort((a, b) => (a.rect.top - b.rect.top) || (a.rect.left - b.rect.left));

        const target = grid.find((entry) => entry.card === targetCard);
        if (!target) {
            return null;
        }

        const rowTops = [];
        const columnLefts = [];

        for (const entry of grid) {
            if (!rowTops.some((top) => Math.abs(top - entry.rect.top) < averageWidth * 0.35)) {
                rowTops.push(entry.rect.top);
            }

            if (!columnLefts.some((left) => Math.abs(left - entry.rect.left) < averageWidth * 0.35)) {
                columnLefts.push(entry.rect.left);
            }
        }

        rowTops.sort((a, b) => a - b);
        columnLefts.sort((a, b) => a - b);

        const row = rowTops.findIndex((top) => Math.abs(top - target.rect.top) < averageWidth * 0.35);
        const column = columnLefts.findIndex((left) => Math.abs(left - target.rect.left) < averageWidth * 0.35);
        const columns = Math.max(1, Math.min(8, columnLefts.length || 5));

        if (row < 0 || column < 0) {
            return null;
        }

        const slot = normalizeSlot(5 + (row * columns) + column);
        return slot && (primarySlots[slot] || Object.keys(primarySlots).length === 0) ? slot : null;
    }

    function setSelected(element, slot) {
        if (!slot) {
            return;
        }

        if (lastCard && lastCard.classList) {
            lastCard.classList.remove(selectedClass);
        }

        lastSlot = slot;
        lastCard = findItemCard(element);

        if (lastCard && lastCard.classList) {
            lastCard.classList.add(selectedClass);
        }
    }

    function getDestroyButton() {
        return document.getElementById(buttonId);
    }

    function isFormField(element) {
        if (!element || element.nodeType !== 1) {
            return false;
        }

        if (element.isContentEditable) {
            return true;
        }

        return !!element.closest("input,textarea,select,button");
    }

    function isPointInsideButton(x, y) {
        const button = getDestroyButton();
        if (!button || !Number.isFinite(x) || !Number.isFinite(y)) {
            return false;
        }

        const rect = button.getBoundingClientRect();
        const margin = 8;

        return x >= rect.left - margin &&
            x <= rect.right + margin &&
            y >= rect.top - margin &&
            y <= rect.bottom + margin;
    }

    function setDropHover(active) {
        const button = getDestroyButton();
        if (button) {
            button.classList.toggle("of-destroy-hover", !!active);
        }
    }

    function trackPointer(event) {
        if (!event) {
            return;
        }

        if (Number.isFinite(event.clientX) && Number.isFinite(event.clientY)) {
            pointerX = event.clientX;
            pointerY = event.clientY;
        }

        if (inventoryOpen && draggingItem) {
            setDropHover(isPointInsideButton(pointerX, pointerY));
        }
    }

    function readAmount() {
        const amountInput = document.querySelector("#remove-item") ||
            Array.from(document.querySelectorAll("input")).find((input) => {
                const placeholder = String(input.getAttribute("placeholder") || "").toLowerCase();
                return placeholder.includes("quantidade") || placeholder.includes("amount");
            });

        const value = amountInput ? Number.parseInt(amountInput.value, 10) : 1;
        return Number.isFinite(value) && value > 0 ? value : 1;
    }

    function findTextElement(text) {
        const filter = window.NodeFilter || { SHOW_TEXT: 4, FILTER_ACCEPT: 1, FILTER_REJECT: 2 };
        const walker = document.createTreeWalker(document.body, filter.SHOW_TEXT, {
            acceptNode(node) {
                return node.nodeValue && node.nodeValue.trim() === text ? filter.FILTER_ACCEPT : filter.FILTER_REJECT;
            }
        });

        const textNode = walker.nextNode();
        return textNode ? textNode.parentElement : null;
    }

    function findActionButton(text) {
        let element = findTextElement(text);
        let depth = 0;

        while (element && depth < 5) {
            const className = String(element.className || "");
            if (className.includes("h-[3.75rem]") || className.includes("w-[12.125rem]") || element.tagName === "BUTTON") {
                return element;
            }

            element = element.parentElement;
            depth += 1;
        }

        return null;
    }

    function setFeedback(message, danger) {
        const button = document.getElementById(buttonId);
        if (!button) {
            return;
        }

        button.textContent = message;
        button.classList.toggle("of-destroy-error", !!danger);

        if (feedbackTimer) {
            clearTimeout(feedbackTimer);
        }

        feedbackTimer = setTimeout(() => {
            const current = document.getElementById(buttonId);
            if (current) {
                current.textContent = "Destruir item";
                current.classList.remove("of-destroy-error");
            }
        }, 2200);
    }

    function dispatchSafeEvent(target, type, options) {
        if (!target || !target.dispatchEvent) {
            return;
        }

        try {
            let event;
            if (type.startsWith("pointer") && typeof PointerEvent === "function") {
                event = new PointerEvent(type, options);
            } else if (type.startsWith("mouse") && typeof MouseEvent === "function") {
                event = new MouseEvent(type, options);
            } else {
                event = new Event(type, { bubbles: true, cancelable: true });
            }

            target.dispatchEvent(event);
        } catch (error) {
            try {
                target.dispatchEvent(new Event(type, { bubbles: true, cancelable: true }));
            } catch (_) {}
        }
    }

    function clearNativeDragState(sourceCard) {
        clearingDrag = true;
        draggingItem = false;
        setDropHover(false);

        const x = Number.isFinite(pointerX) ? pointerX : dragStartX;
        const y = Number.isFinite(pointerY) ? pointerY : dragStartY;
        const pointTarget = document.elementFromPoint && Number.isFinite(x) && Number.isFinite(y) ? document.elementFromPoint(x, y) : null;
        const eventOptions = {
            bubbles: true,
            cancelable: true,
            clientX: Number.isFinite(x) ? x : 0,
            clientY: Number.isFinite(y) ? y : 0,
            pointerId: 1,
            pointerType: "mouse",
            button: 0,
            buttons: 0
        };

        for (const target of [sourceCard, pointTarget, document.body, document.documentElement, document]) {
            dispatchSafeEvent(target, "pointerup", eventOptions);
            dispatchSafeEvent(target, "mouseup", eventOptions);
            dispatchSafeEvent(target, "dragend", eventOptions);
        }

        setTimeout(() => {
            clearingDrag = false;
        }, 120);
    }

    async function destroySelected(event) {
        if (event && event.type === "click") {
            event.preventDefault();
        }

        if (destroying) {
            return;
        }

        if (Date.now() - lastDropAt < 250) {
            return;
        }

        lastDropAt = Date.now();

        if (!inventoryOpen || !lastSlot) {
            setFeedback("Selecione um item", true);
            return;
        }

        destroying = true;
        setFeedback("Destruindo...", false);

        try {
            const success = await post("Destroy", { Slot: lastSlot, Amount: readAmount() });
            if (success) {
                const sourceCard = lastCard;
                setFeedback("Item destruido", false);
                if (lastCard && lastCard.classList) {
                    lastCard.classList.remove(selectedClass);
                }

                lastSlot = null;
                lastCard = null;
                clearNativeDragState(sourceCard);
            } else {
                setFeedback("Nao destruiu", true);
            }
        } catch (error) {
            setFeedback("Falha", true);
        } finally {
            setDropHover(false);
            draggingItem = false;
            setTimeout(() => {
                destroying = false;
            }, 450);
        }
    }

    function maybeDestroyOnDrop(event) {
        if (clearingDrag) {
            return;
        }

        if (event && isFormField(event.target) && !event.target.closest(`#${buttonId}`)) {
            setDropHover(false);
            draggingItem = false;

            if (lastCard && lastCard.classList) {
                lastCard.classList.add(selectedClass);
            }

            return;
        }

        trackPointer(event);

        if (inventoryOpen && draggingItem && !lastSlot) {
            const fallbackSlot = findSlotAtPoint(dragStartX, dragStartY);
            if (fallbackSlot) {
                lastSlot = fallbackSlot;
            }
        }

        if (!inventoryOpen || !draggingItem || !lastSlot) {
            setDropHover(false);
            draggingItem = false;
            return;
        }

        if (!isPointInsideButton(pointerX, pointerY)) {
            setDropHover(false);
            draggingItem = false;
            return;
        }

        destroySelected(event);
    }

    function addStyle() {
        if (document.getElementById("of-destroy-style")) {
            return;
        }

        const style = document.createElement("style");
        style.id = "of-destroy-style";
        style.textContent = [
            `.${selectedClass}{box-shadow:0 0 0 .125rem rgba(255,90,90,.95),0 0 1.4rem rgba(255,65,65,.35)!important;}`,
            `#${buttonId}{user-select:none;}`,
            `#${buttonId}:hover{background:rgba(185,28,28,.72)!important;border-color:rgba(255,120,120,.95)!important;color:#fff!important;}`,
            `#${buttonId}.of-destroy-hover{background:rgba(185,28,28,.82)!important;border-color:rgba(255,150,150,.98)!important;color:#fff!important;box-shadow:0 0 0 .125rem rgba(255,110,110,.75),0 0 1.2rem rgba(255,55,55,.32)!important;}`,
            `#${buttonId}.of-destroy-error{background:rgba(180,95,12,.78)!important;border-color:rgba(255,205,90,.95)!important;color:#fff!important;}`
        ].join("");
        document.head.appendChild(style);
    }

    function buildButtonFrom(existingButton) {
        const button = existingButton.cloneNode(true);
        button.id = buttonId;
        button.textContent = "Destruir item";
        button.removeAttribute("disabled");
        button.setAttribute("title", "Arraste um item aqui ou selecione um item e clique para destruir.");
        button.classList.add("of-destroy-action");
        button.addEventListener("mouseup", destroySelected, true);
        button.addEventListener("pointerup", destroySelected, true);
        button.addEventListener("click", destroySelected, true);
        button.addEventListener("dragover", (event) => {
            event.preventDefault();
            trackPointer(event);
        }, true);
        button.addEventListener("dragenter", (event) => {
            event.preventDefault();
            trackPointer(event);
            setDropHover(true);
        }, true);
        button.addEventListener("dragleave", () => setDropHover(false), true);
        button.addEventListener("drop", maybeDestroyOnDrop, true);
        return button;
    }

    function ensureButton() {
        if (!inventoryOpen || document.getElementById(buttonId)) {
            return;
        }

        const sendButton = findActionButton("Enviar item");
        const useButton = findActionButton("Usar item");
        const sourceButton = sendButton || useButton;

        if (!sourceButton || !sourceButton.parentElement) {
            return;
        }

        const button = buildButtonFrom(sourceButton);
        sourceButton.insertAdjacentElement("afterend", button);
    }

    function removeButton() {
        const button = document.getElementById(buttonId);
        if (button) {
            button.remove();
        }

        if (lastCard && lastCard.classList) {
            lastCard.classList.remove(selectedClass);
        }

        lastSlot = null;
        lastCard = null;
    }

    function setOpen(open) {
        inventoryOpen = open;

        if (open) {
            addStyle();
            setTimeout(ensureButton, 50);
            setTimeout(ensureButton, 250);
            setTimeout(ensureButton, 800);
        } else {
            removeButton();
        }
    }

    function watchLayout() {
        if (observer) {
            return;
        }

        observer = new MutationObserver(() => {
            if (inventoryOpen) {
                ensureButton();
            }
        });

        observer.observe(document.body, { childList: true, subtree: true });
    }

    function rememberSlots(message) {
        const payload = message && (message.Payload || message.payload);
        const primary = payload && (payload.Primary || payload.primary);
        const data = primary && (primary.Data || primary.data);

        if (data && typeof data === "object") {
            primarySlots = data;
        }
    }

    function startDrag(event) {
        trackPointer(event);

        if (!inventoryOpen || event.target.closest(`#${buttonId}`)) {
            return;
        }

        if (isFormField(event.target)) {
            if (lastCard && lastCard.classList) {
                lastCard.classList.add(selectedClass);
            }

            return;
        }

        dragStartX = pointerX;
        dragStartY = pointerY;

        const slot = findSlot(event.target) || findSlotAtPoint(pointerX, pointerY);
        if (slot) {
            draggingItem = true;
            setSelected(event.target, slot);
        }
    }

    document.addEventListener("mousedown", (event) => {
        startDrag(event);
    }, true);

    document.addEventListener("pointerdown", (event) => {
        startDrag(event);
    }, true);

    document.addEventListener("dragstart", (event) => {
        startDrag(event);
    }, true);

    document.addEventListener("mousemove", trackPointer, true);
    document.addEventListener("pointermove", trackPointer, true);
    document.addEventListener("dragover", trackPointer, true);
    document.addEventListener("mouseup", maybeDestroyOnDrop, true);
    document.addEventListener("pointerup", maybeDestroyOnDrop, true);
    document.addEventListener("drop", maybeDestroyOnDrop, true);
    document.addEventListener("dragend", maybeDestroyOnDrop, true);
    document.addEventListener("focusin", (event) => {
        if (inventoryOpen && isFormField(event.target) && lastCard && lastCard.classList) {
            lastCard.classList.add(selectedClass);
        }
    }, true);

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        if (data.Action === "Open") {
            rememberSlots(data);
            setOpen(true);
        } else if (data.Action === "Close") {
            primarySlots = {};
            setOpen(false);
        } else if (data.Action === "Backpack") {
            primarySlots = {};
            setTimeout(ensureButton, 50);
        }
    });

    window.__ofDestroyInventoryItem = function (slot, amount) {
        lastSlot = normalizeSlot(slot);
        return post("Destroy", { Slot: lastSlot, Amount: amount || 1 });
    };

    addStyle();
    watchLayout();
})();

(function () {
    "use strict";

    // O fluxo de compra da loja fica em of-shop-buy.js. Esta copia antiga
    // foi mantida desativada para evitar dois botoes "Comprar" competindo.
    return;

    const buyButtonId = "of-shop-buy";
    const selectedClass = "of-shop-selected";
    let shopOpen = false;
    let shopItems = [];
    let selectedItem = null;
    let selectedCard = null;
    let buying = false;
    let feedbackTimer = null;

    function post(resource, name, data) {
        return fetch(`https://${resource}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {})
        }).then((response) => response.json().catch(() => response.text()).catch(() => false));
    }

    function normalizeItems(data) {
        const secondary = data && (data.Secondary || data.secondary);
        const raw = secondary && (secondary.Data || secondary.data);

        if (!raw) {
            shopItems = [];
            return;
        }

        if (Array.isArray(raw)) {
            shopItems = raw.filter(Boolean);
            return;
        }

        shopItems = Object.keys(raw)
            .sort((a, b) => Number(a) - Number(b))
            .map((key) => raw[key])
            .filter(Boolean);
    }

    function refreshShopItems() {
        if (!shopOpen) {
            return;
        }

        post("shops", "Mount", {})
            .then((data) => {
                normalizeItems(data);
                setTimeout(ensureBuyButton, 50);
            })
            .catch(() => {});
    }

    function readAmount() {
        const amountInput = document.querySelector("#remove-item") ||
            Array.from(document.querySelectorAll("input")).find((input) => {
                const placeholder = String(input.getAttribute("placeholder") || "").toLowerCase();
                return placeholder.includes("quantidade") || placeholder.includes("amount");
            });

        const value = amountInput ? Number.parseInt(amountInput.value, 10) : 1;
        return Number.isFinite(value) && value > 0 ? value : 1;
    }

    function findTextElement(text) {
        const filter = window.NodeFilter || { SHOW_TEXT: 4, FILTER_ACCEPT: 1, FILTER_REJECT: 2 };
        const walker = document.createTreeWalker(document.body, filter.SHOW_TEXT, {
            acceptNode(node) {
                return node.nodeValue && node.nodeValue.trim() === text ? filter.FILTER_ACCEPT : filter.FILTER_REJECT;
            }
        });

        const textNode = walker.nextNode();
        return textNode ? textNode.parentElement : null;
    }

    function findActionButton(text) {
        let element = findTextElement(text);
        let depth = 0;

        while (element && depth < 5) {
            const className = String(element.className || "");
            if (className.includes("h-[3.75rem]") || className.includes("w-[12.125rem]") || element.tagName === "BUTTON") {
                return element;
            }

            element = element.parentElement;
            depth += 1;
        }

        return null;
    }

    function findItemCard(element) {
        let node = element;
        let depth = 0;

        while (node && depth < 8) {
            const className = String(node.className || "");
            if (className.includes("aspect-square") && className.includes("rounded")) {
                return node;
            }

            node = node.parentElement;
            depth += 1;
        }

        return null;
    }

    function isVisibleCard(element) {
        if (!element || !element.getBoundingClientRect) {
            return false;
        }

        const rect = element.getBoundingClientRect();
        return rect.width >= 40 &&
            rect.height >= 40 &&
            rect.bottom > 0 &&
            rect.right > 0 &&
            rect.top < window.innerHeight &&
            rect.left < window.innerWidth;
    }

    function secondaryCards() {
        const actionButton = findActionButton("Usar item") || findActionButton("Enviar item") || document.getElementById(buyButtonId);
        const actionTop = actionButton ? actionButton.getBoundingClientRect().top : window.innerHeight;

        return Array.from(document.querySelectorAll(".aspect-square"))
            .filter((card) => String(card.className || "").includes("rounded"))
            .filter(isVisibleCard)
            .filter((card) => {
                const rect = card.getBoundingClientRect();
                const centerX = rect.left + (rect.width / 2);
                return rect.top > 90 && rect.top < actionTop - 8 && centerX > window.innerWidth * 0.52;
            })
            .sort((a, b) => {
                const ar = a.getBoundingClientRect();
                const br = b.getBoundingClientRect();
                return (ar.top - br.top) || (ar.left - br.left);
            });
    }

    function setSelected(card, item) {
        if (!item || !card) {
            return;
        }

        if (selectedCard && selectedCard.classList) {
            selectedCard.classList.remove(selectedClass);
        }

        selectedItem = item.key || item.Item || item.item || null;
        selectedCard = card;

        if (selectedCard && selectedCard.classList) {
            selectedCard.classList.add(selectedClass);
        }
    }

    function selectFromPoint(target) {
        if (!shopOpen) {
            return;
        }

        const card = findItemCard(target);
        if (!card) {
            return;
        }

        const cards = secondaryCards();
        const index = cards.indexOf(card);
        if (index < 0 || !shopItems[index]) {
            return;
        }

        setSelected(card, shopItems[index]);
    }

    function setFeedback(message, danger) {
        const button = document.getElementById(buyButtonId);
        if (!button) {
            return;
        }

        button.textContent = message;
        button.classList.toggle("of-shop-error", !!danger);

        if (feedbackTimer) {
            clearTimeout(feedbackTimer);
        }

        feedbackTimer = setTimeout(() => {
            const current = document.getElementById(buyButtonId);
            if (current) {
                current.textContent = "Comprar";
                current.classList.remove("of-shop-error");
            }
        }, 2200);
    }

    async function buySelected(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }

        if (buying) {
            return;
        }

        if (!shopOpen || !selectedItem) {
            setFeedback("Selecione item", true);
            return;
        }

        buying = true;
        setFeedback("Comprando...", false);

        try {
            const success = await post("shops", "DirectBuy", {
                Item: selectedItem,
                Amount: readAmount()
            });

            if (success) {
                setFeedback("Comprado", false);
                refreshShopItems();
            } else {
                setFeedback("Nao comprou", true);
            }
        } catch (error) {
            setFeedback("Falha", true);
        } finally {
            setTimeout(() => {
                buying = false;
            }, 400);
        }
    }

    function addStyle() {
        if (document.getElementById("of-shop-buy-style")) {
            return;
        }

        const style = document.createElement("style");
        style.id = "of-shop-buy-style";
        style.textContent = [
            `.${selectedClass}{box-shadow:0 0 0 .125rem rgba(34,197,94,.95),0 0 1.4rem rgba(34,197,94,.35)!important;}`,
            `#${buyButtonId}{user-select:none;}`,
            `#${buyButtonId}:hover{background:rgba(22,163,74,.72)!important;border-color:rgba(74,222,128,.95)!important;color:#fff!important;}`,
            `#${buyButtonId}.of-shop-error{background:rgba(180,95,12,.78)!important;border-color:rgba(255,205,90,.95)!important;color:#fff!important;}`
        ].join("");
        document.head.appendChild(style);
    }

    function buildButton(sourceButton) {
        const button = sourceButton.cloneNode(true);
        button.id = buyButtonId;
        button.textContent = "Comprar";
        button.removeAttribute("disabled");
        button.setAttribute("title", "Selecione um item da loja, defina a quantidade e clique para comprar.");
        button.addEventListener("click", buySelected, true);
        button.addEventListener("mouseup", buySelected, true);
        button.addEventListener("pointerup", buySelected, true);
        return button;
    }

    function ensureBuyButton() {
        if (!shopOpen) {
            const existing = document.getElementById(buyButtonId);
            if (existing) {
                existing.remove();
            }
            return;
        }

        if (document.getElementById(buyButtonId)) {
            return;
        }

        const destroyButton = document.getElementById("of-inventory-destroy");
        const sourceButton = destroyButton || findActionButton("Usar item") || findActionButton("Enviar item");
        if (!sourceButton || !sourceButton.parentElement) {
            return;
        }

        sourceButton.insertAdjacentElement("afterend", buildButton(sourceButton));
    }

    function clearSelection() {
        if (selectedCard && selectedCard.classList) {
            selectedCard.classList.remove(selectedClass);
        }

        selectedItem = null;
        selectedCard = null;
        shopItems = [];
    }

    function setShopOpen(open) {
        shopOpen = open;
        addStyle();

        if (open) {
            setTimeout(refreshShopItems, 80);
            setTimeout(refreshShopItems, 350);
            setTimeout(ensureBuyButton, 700);
        } else {
            clearSelection();
            ensureBuyButton();
        }
    }

    document.addEventListener("mousedown", (event) => selectFromPoint(event.target), true);
    document.addEventListener("pointerdown", (event) => selectFromPoint(event.target), true);

    const observer = new MutationObserver(() => {
        if (shopOpen) {
            ensureBuyButton();
        }
    });

    observer.observe(document.body, { childList: true, subtree: true });

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        const payload = data.Payload || data.payload || {};

        if (data.Action === "Open") {
            setShopOpen(payload.Type === "Shops" || payload.Resource === "shops");
        } else if (data.Action === "Close") {
            setShopOpen(false);
        } else if (data.Action === "Backpack" && shopOpen) {
            setTimeout(refreshShopItems, 80);
        }
    });

    addStyle();
})();
