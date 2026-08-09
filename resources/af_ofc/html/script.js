(() => {
	"use strict";

	const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "af_ofc";
	const byId = (id) => document.getElementById(id);
	const fighters = Array.from(document.querySelectorAll("[data-side]"));
	const organizerButtons = Array.from(document.querySelectorAll("[data-organizer-action]"));
	const organizerRoutes = new Set(["announceEvent", "openBets", "closeBets", "startFight"]);

	const state = {
		open: false,
		mode: null,
		selectedSide: null,
		snapshotRevision: 0,
		snapshot: null,
		requestSequence: 0,
		pending: new Map(),
		toastTimer: null,
		texts: {}
	};

	const safeString = (value, fallback = "") => typeof value === "string" ? value : fallback;
	const safeNumber = (value) => Number.isFinite(Number(value)) ? Number(value) : 0;

	const setText = (id, value) => {
		const element = byId(id);
		if (element) element.textContent = safeString(value, String(value ?? ""));
	};

	const money = (value) => new Intl.NumberFormat("pt-BR", {
		style: "currency",
		currency: "BRL",
		maximumFractionDigits: 0
	}).format(safeNumber(value));

	const nextRequestId = () => {
		state.requestSequence += 1;
		if (state.requestSequence > 2147483647) state.requestSequence = 1;
		return state.requestSequence;
	};

	const post = async (name, payload = {}) => {
		try {
			const response = await fetch(`https://${resource}/${name}`, {
				method: "POST",
				headers: { "Content-Type": "application/json; charset=UTF-8" },
				body: JSON.stringify(payload)
			});
			return await response.json();
		} catch (_) {
			return { Accepted: false };
		}
	};

	const showToast = (message) => {
		const toast = byId("toast");
		const paragraph = toast?.querySelector("p");
		if (!toast || !paragraph) return;

		paragraph.textContent = safeString(message, state.texts.ToastFallback || "");
		toast.classList.add("is-visible");
		window.clearTimeout(state.toastTimer);
		state.toastTimer = window.setTimeout(() => toast.classList.remove("is-visible"), 4200);
	};

	const setDocumentVisibility = (visible) => {
		document.body.classList.toggle("ui-open", visible);
		document.body.classList.toggle("ui-closed", !visible);
		document.body.setAttribute("aria-hidden", visible ? "false" : "true");
	};

	const setModal = (id, visible) => {
		const modal = byId(id);
		if (modal) modal.hidden = !visible;
	};

	const closeModals = () => {
		setModal("create-event-modal", false);
		setModal("cancel-event-modal", false);
	};

	const setBetProcessing = (processing) => {
		const button = byId("bet-button");
		if (!button) return;

		button.classList.toggle("is-processing", processing);
		button.querySelector("span").textContent = processing
			? safeString(state.texts.BetProcessing)
			: safeString(state.texts.BetButton);
	};

	const close = () => {
		setDocumentVisibility(false);
		state.open = false;
		state.mode = null;
		state.snapshot = null;
		state.selectedSide = null;
		state.pending.clear();
		byId("app")?.classList.remove("is-open");
		byId("app")?.setAttribute("aria-hidden", "true");
		byId("public-view").hidden = true;
		byId("organizer-view").hidden = true;
		byId("toast")?.classList.remove("is-visible");
		closeModals();
		setBetProcessing(false);
		organizerButtons.forEach((button) => button.classList.remove("is-processing"));
	};

	const requestClose = () => {
		close();
		void post("close");
	};

	const setSelection = (side, snapshot) => {
		state.selectedSide = side === "A" || side === "B" ? side : null;
		fighters.forEach((fighter) => fighter.classList.toggle("is-selected", fighter.dataset.side === state.selectedSide));

		const selected = state.selectedSide === "A"
			? snapshot?.Event?.FighterA?.Name
			: state.selectedSide === "B"
				? snapshot?.Event?.FighterB?.Name
				: state.texts.NoSelection;
		setText("selected-fighter", selected);
	};

	const applyCommonTexts = (texts) => {
		state.texts = texts;
		document.title = safeString(texts.BrandName);
		setText("brand-short", texts.Brand);
		setText("brand-kicker", texts.BrandKicker);
		setText("brand-name", texts.BrandName);
		setText("live-signal", texts.LiveSignal);
		setText("versus", texts.Versus);
		setText("organizer-versus", texts.Versus);
		byId("close-button")?.setAttribute("aria-label", safeString(texts.Close));
		byId("close-button")?.setAttribute("title", safeString(texts.Close));
	};

	const renderPublic = (snapshot, view) => {
		const event = snapshot.Event || {};
		const texts = snapshot.Texts || {};
		const fighterA = event.FighterA || {};
		const fighterB = event.FighterB || {};

		setText("event-status", event.Status);
		setText("event-schedule", event.Schedule);
		setText("event-name", event.Name);
		setText("demo-label", event.DemoLabel);
		setText("fighter-a-corner", fighterA.Corner);
		setText("fighter-a-name", fighterA.Name);
		setText("fighter-a-pool", money(fighterA.Pool));
		setText("fighter-a-odds", fighterA.Odds);
		setText("fighter-b-corner", fighterB.Corner);
		setText("fighter-b-name", fighterB.Name);
		setText("fighter-b-pool", money(fighterB.Pool));
		setText("fighter-b-odds", fighterB.Odds);
		setText("pool-a-label", texts.Pool);
		setText("pool-b-label", texts.Pool);
		setText("odds-a-label", texts.Odds);
		setText("odds-b-label", texts.Odds);
		setText("choose-fighter", texts.ChooseFighter);
		setText("public-tab", texts.PublicTab);
		setText("bet-value-label", texts.BetValue);
		setText("currency", texts.Currency);
		setText("warning-symbol", texts.WarningSymbol);
		setText("financial-warning", texts.FinancialWarning);
		byId("bet-amount").placeholder = safeString(texts.BetPlaceholder);
		setBetProcessing(false);
		setSelection(null, snapshot);

		const betting = byId("betting-block");
		betting?.classList.toggle("is-highlighted", view === "betting");
		betting?.classList.toggle("is-open", snapshot.State === "betting_open");
		byId("public-view").hidden = false;
		byId("organizer-view").hidden = true;
	};

	const setOrganizerActions = (snapshot) => {
		const allowed = snapshot.Actions || {};
		organizerButtons.forEach((button) => {
			const action = safeString(button.dataset.organizerAction);
			const key = action.charAt(0).toUpperCase() + action.slice(1);
			const disabled = action !== "startFight" && allowed[key] !== true;
			button.disabled = disabled;
			button.setAttribute("aria-disabled", disabled ? "true" : "false");
		});
	};

	const renderOrganizer = (snapshot) => {
		const event = snapshot.Event || {};
		const texts = snapshot.Texts || {};
		const fighterA = event.FighterA || {};
		const fighterB = event.FighterB || {};

		setText("organizer-kicker", texts.OrganizerKicker);
		setText("organizer-title", texts.OrganizerTitle);
		setText("organizer-description", texts.OrganizerDescription);
		setText("organizer-tab", texts.OrganizerTab);
		setText("event-status-label", texts.EventStatus);
		setText("organizer-event-status", event.Status);
		setText("organizer-event-name", event.Name);
		setText("organizer-fighter-a", fighterA.Name);
		setText("organizer-fighter-b", fighterB.Name);
		setText("checkin-status-label", texts.CheckInStatus);
		setText("checkin-slots", texts.CheckInSlots);
		setText("checkin-a-label", `${texts.FighterA}${fighterA.Passport ? ` #${fighterA.Passport}` : ""}`);
		setText("checkin-b-label", `${texts.FighterB}${fighterB.Passport ? ` #${fighterB.Passport}` : ""}`);
		setText("checkin-a-value", fighterA.CheckedIn ? texts.BackendValue : texts.Pending);
		setText("checkin-b-value", fighterB.CheckedIn ? texts.BackendValue : texts.Pending);
		setText("system-status-label", texts.SystemStatus);
		setText("system-indicators", texts.SystemIndicators);
		setText("backend-label", texts.Backend);
		setText("backend-value", texts.BackendValue);
		setText("finance-label", texts.Financial);
		setText("finance-value", texts.FinancialValue);
		setText("database-label", texts.Database);
		setText("database-value", texts.DatabaseValue);
		setText("phase-label", texts.Phase);
		setText("phase-value", texts.PhaseValue);
		setText("future-actions-label", texts.FutureActions);
		setText("locked-label", texts.Locked);
		setText("action-create", texts.CreateEvent);
		setText("action-announce", texts.Announce);
		setText("action-open-bets", texts.OpenBets);
		setText("action-close-bets", texts.CloseBets);
		setText("action-start-fight", texts.StartFight);
		setText("action-cancel-event", texts.CancelEvent);
		setText("create-event-title", texts.CreateEventTitle);
		setText("event-title-label", texts.EventTitleLabel);
		setText("fighter-a-passport-label", texts.FighterAPassport);
		setText("fighter-b-passport-label", texts.FighterBPassport);
		setText("confirm-create-event", texts.ConfirmCreate);
		setText("cancel-create-event", texts.CancelForm);
		setText("cancel-confirmation-title", texts.CancelConfirmationTitle);
		setText("cancel-confirmation-text", texts.CancelConfirmationText);
		setText("confirm-cancel-event", texts.ConfirmCancel);
		setText("keep-event", texts.KeepEvent);
		byId("event-title-input").placeholder = safeString(texts.EventTitlePlaceholder);
		setOrganizerActions(snapshot);

		byId("public-view").hidden = true;
		byId("organizer-view").hidden = false;
	};

	const renderSnapshot = (snapshot, view) => {
		const revision = Number(snapshot?.Revision);
		const mode = snapshot?.Mode;
		if (!snapshot || !Number.isInteger(revision) || (mode !== "public" && mode !== "organizer")) return false;
		if (revision < state.snapshotRevision || (state.mode && mode !== state.mode)) return false;

		applyCommonTexts(snapshot.Texts || {});
		if (mode === "organizer") renderOrganizer(snapshot);
		else renderPublic(snapshot, view);
		state.snapshotRevision = revision;
		state.snapshot = snapshot;
		state.mode = mode;
		return true;
	};

	const open = (payload) => {
		try {
			if (!renderSnapshot(payload?.Snapshot, payload?.View)) {
				requestClose();
				return;
			}
		} catch (_) {
			requestClose();
			return;
		}

		state.open = true;
		byId("app")?.classList.add("is-open");
		byId("app")?.setAttribute("aria-hidden", "false");
		setDocumentVisibility(true);
	};

	const sendOrganizerAction = async (route, payload = {}) => {
		if (!state.open || state.mode !== "organizer" || state.pending.has(route)) return;
		const requestId = nextRequestId();
		state.pending.set(route, requestId);
		organizerButtons.find((button) => button.dataset.organizerAction === route)?.classList.add("is-processing");

		const result = await post(route, { RequestId: requestId, ...payload });
		if (!result?.Accepted && state.pending.get(route) === requestId) {
			state.pending.delete(route);
			organizerButtons.find((button) => button.dataset.organizerAction === route)?.classList.remove("is-processing");
			showToast(state.texts.ToastFallback);
		}
	};

	fighters.forEach((fighter) => {
		fighter.addEventListener("click", () => {
			if (!state.open || state.mode !== "public") return;
			setSelection(fighter.dataset.side, state.snapshot);
		});
	});

	byId("bet-button")?.addEventListener("click", async () => {
		if (!state.open || state.mode !== "public" || state.pending.has("bet")) return;
		if (!state.selectedSide) {
			showToast(state.texts.SelectRequired);
			return;
		}

		const requestId = nextRequestId();
		state.pending.set("bet", requestId);
		setBetProcessing(true);
		const result = await post("attemptBet", {
			RequestId: requestId,
			Side: state.selectedSide,
			Amount: Number(byId("bet-amount")?.value)
		});
		if (!result?.Accepted && state.pending.get("bet") === requestId) {
			state.pending.delete("bet");
			setBetProcessing(false);
			showToast(state.texts.ToastFallback);
		}
	});

	organizerButtons.forEach((button) => {
		button.addEventListener("click", () => {
			if (button.disabled || !state.open || state.mode !== "organizer") return;
			const action = safeString(button.dataset.organizerAction);
			if (action === "createEvent") {
				setModal("create-event-modal", true);
				byId("event-title-input")?.focus();
				return;
			}
			if (action === "cancelEvent") {
				setModal("cancel-event-modal", true);
				return;
			}
			if (organizerRoutes.has(action)) void sendOrganizerAction(action);
		});
	});

	byId("create-event-form")?.addEventListener("submit", (event) => {
		event.preventDefault();
		if (state.pending.has("createEvent")) return;
		setModal("create-event-modal", false);
		void sendOrganizerAction("createEvent", {
			Title: safeString(byId("event-title-input")?.value),
			FighterA: Number(byId("fighter-a-passport")?.value),
			FighterB: Number(byId("fighter-b-passport")?.value)
		});
	});

	byId("cancel-create-event")?.addEventListener("click", () => setModal("create-event-modal", false));
	byId("keep-event")?.addEventListener("click", () => setModal("cancel-event-modal", false));
	byId("confirm-cancel-event")?.addEventListener("click", () => {
		setModal("cancel-event-modal", false);
		void sendOrganizerAction("cancelEvent");
	});
	byId("close-button")?.addEventListener("click", requestClose);

	document.addEventListener("keydown", (event) => {
		if (event.key !== "Escape" || !state.open) return;
		if (!byId("create-event-modal")?.hidden || !byId("cancel-event-modal")?.hidden) closeModals();
		else requestClose();
	});

	window.addEventListener("error", requestClose);
	window.addEventListener("unhandledrejection", requestClose);

	window.addEventListener("message", (event) => {
		const data = event.data;
		if (!data || typeof data !== "object") return;

		if (data.Action === "open") {
			open(data.Payload);
			return;
		}

		if (data.Action === "close") {
			close();
			return;
		}

		if (data.Action === "snapshot") {
			if (!state.open) return;
			try { renderSnapshot(data.Payload); } catch (_) { requestClose(); }
			return;
		}

		if (data.Action === "actionResult") {
			const payload = data.Payload || {};
			const kind = safeString(payload.Kind);
			const requestId = Number(payload.RequestId);
			if (state.pending.get(kind) !== requestId) return;

			state.pending.delete(kind);
			if (kind === "bet") setBetProcessing(false);
			organizerButtons.find((button) => button.dataset.organizerAction === kind)?.classList.remove("is-processing");
			showToast(payload.Message);
		}
	});

	close();
})();
