(() => {
	"use strict";

	const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "af_ofc";
	const byId = (id) => document.getElementById(id);
	const fighters = Array.from(document.querySelectorAll("[data-side]"));
	const organizerButtons = Array.from(document.querySelectorAll("[data-organizer-action]"));

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

	const close = () => {
		state.open = false;
		state.mode = null;
		state.pending.clear();
		byId("app")?.classList.remove("is-open");
		byId("app")?.setAttribute("aria-hidden", "true");
		byId("public-view").hidden = true;
		byId("organizer-view").hidden = true;
		byId("toast")?.classList.remove("is-visible");
		setBetProcessing(false);
		organizerButtons.forEach((button) => button.classList.remove("is-processing"));
	};

	const setBetProcessing = (processing) => {
		const button = byId("bet-button");
		if (!button) return;

		button.classList.toggle("is-processing", processing);
		button.querySelector("span").textContent = processing
			? safeString(state.texts.BetProcessing)
			: safeString(state.texts.BetButton);
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
		byId("public-view").hidden = false;
		byId("organizer-view").hidden = true;
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
		setText("checkin-a-label", texts.FighterA);
		setText("checkin-b-label", texts.FighterB);
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
		setText("action-start-fight", texts.StartFight);
		setText("action-cancel-event", texts.CancelEvent);

		byId("public-view").hidden = true;
		byId("organizer-view").hidden = false;
	};

	const open = (payload) => {
		const snapshot = payload?.Snapshot;
		const revision = Number(snapshot?.Revision);
		if (!snapshot || !Number.isInteger(revision) || revision < state.snapshotRevision) return;

		state.snapshotRevision = revision;
		state.snapshot = snapshot;
		state.open = true;
		state.mode = snapshot.Mode;
		applyCommonTexts(snapshot.Texts || {});

		if (snapshot.Mode === "organizer") renderOrganizer(snapshot);
		else renderPublic(snapshot, payload.View);

		byId("app")?.classList.add("is-open");
		byId("app")?.setAttribute("aria-hidden", "false");
	};

	fighters.forEach((fighter) => {
		fighter.addEventListener("click", () => {
			if (!state.open || state.mode !== "public") return;
			const current = fighter.dataset.side;
			setSelection(current, state.snapshot);
		});
	});

	byId("bet-button")?.addEventListener("click", async () => {
		if (!state.open || state.mode !== "public" || state.pending.has("bet")) return;

		if (!state.selectedSide) {
			showToast(state.texts.SelectRequired);
			return;
		}

		const amount = Number(byId("bet-amount")?.value);
		const requestId = nextRequestId();
		state.pending.set("bet", requestId);
		setBetProcessing(true);

		const result = await post("attemptBet", { RequestId: requestId, Side: state.selectedSide, Amount: amount });
		if (!result?.Accepted && state.pending.get("bet") === requestId) {
			state.pending.delete("bet");
			setBetProcessing(false);
			showToast(state.texts.ToastFallback);
		}
	});

	organizerButtons.forEach((button) => {
		button.addEventListener("click", async () => {
			if (!state.open || state.mode !== "organizer" || state.pending.has("organizer")) return;

			const action = safeString(button.dataset.organizerAction);
			const requestId = nextRequestId();
			state.pending.set("organizer", requestId);
			button.classList.add("is-processing");

			const result = await post("organizerPreview", { RequestId: requestId, Action: action });
			if (!result?.Accepted && state.pending.get("organizer") === requestId) {
				state.pending.delete("organizer");
				button.classList.remove("is-processing");
				showToast(state.texts.ToastFallback);
			}
		});
	});

	byId("close-button")?.addEventListener("click", () => post("close"));

	document.addEventListener("keydown", (event) => {
		if (event.key === "Escape" && state.open) post("close");
	});

	window.addEventListener("message", (event) => {
		const data = event.data;
		if (!data || typeof data !== "object") return;

		if (data.Action === "open") {
			open(data.Payload);
			return;
		}

		if (data.Action === "close") {
			state.snapshot = null;
			close();
			return;
		}

		if (data.Action === "actionResult") {
			const payload = data.Payload || {};
			const kind = safeString(payload.Kind);
			const requestId = Number(payload.RequestId);
			if (state.pending.get(kind) !== requestId) return;

			state.pending.delete(kind);
			if (kind === "bet") setBetProcessing(false);
			if (kind === "organizer") organizerButtons.forEach((button) => button.classList.remove("is-processing"));
			showToast(payload.Message);
		}
	});

	close();
})();
