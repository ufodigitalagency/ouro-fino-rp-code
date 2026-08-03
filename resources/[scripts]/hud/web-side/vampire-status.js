(() => {
    let root;
    let progressRing;
    let count;
    let state = null;
    let rechargeEndsAt = 0;
    let hudVisible = false;

    /* ── Bat SVG icon (vampire silhouette) ── */
    const BAT_SVG = `<svg class="of-vampire-glyph" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path class="of-vampire-fangs" d="M4.25 5.25C6.62 4.42 9.22 4 12 4s5.38.42 7.75 1.25c-.2 2.88-.78 5.5-1.73 7.72-.9 2.1-2.17 3.9-3.77 5.28l-1.32-5.93a.96.96 0 0 0-1.86 0l-1.32 5.93c-1.6-1.38-2.87-3.18-3.77-5.28-.95-2.22-1.53-4.84-1.73-7.72Zm3.1 2.5c.25 1.7.7 3.25 1.33 4.6l.92-4.1c.18-.82.9-1.4 1.74-1.4h1.32c.84 0 1.56.58 1.74 1.4l.92 4.1c.63-1.35 1.08-2.9 1.33-4.6A15.9 15.9 0 0 0 12 7c-1.63 0-3.18.25-4.65.75Z"/>
        <path class="of-vampire-drop" d="M12 13.7c1.55 1.88 2.45 3.25 2.45 4.38a2.45 2.45 0 1 1-4.9 0c0-1.13.9-2.5 2.45-4.38Z"/>
    </svg>`;

    const ensure = () => {
        if (root) return;

        root = document.createElement("div");
        root.id = "of-vampire-status";
        root.hidden = true;
        root.innerHTML = `
            <svg class="of-vampire-ring" viewBox="0 0 44 44" aria-hidden="true">
                <circle class="of-vampire-track" cx="22" cy="22" r="18"></circle>
                <circle class="of-vampire-progress" cx="22" cy="22" r="18"></circle>
            </svg>
            <div class="of-vampire-icon">${BAT_SVG}</div>
            <span class="of-vampire-count"></span>`;
        document.body.appendChild(root);
        progressRing = root.querySelector(".of-vampire-progress");
        count = root.querySelector(".of-vampire-count");
    };

    const render = () => {
        ensure();
        const visible = Boolean(hudVisible && state && state.Visible);
        root.hidden = !visible;
        if (!visible) return;

        const maximum = Math.max(1, Number(state.Maximum) || 1);
        const charges = Math.max(0, Math.min(maximum, Number(state.Charges) || 0));
        let progress = charges / maximum;

        if (charges === 0 && rechargeEndsAt && state.RechargeDuration) {
            const remaining = Math.max(0, rechargeEndsAt - Date.now());
            progress = Math.max(0, Math.min(1, 1 - remaining / Number(state.RechargeDuration)));
        }

        progressRing.style.strokeDashoffset = String(113.1 * (1 - progress));
        root.classList.toggle("is-active", Boolean(state.Active));
        root.classList.toggle("is-recharging", charges === 0);
        root.classList.toggle("is-burning", Boolean(state.Burning));
        count.textContent = `${charges}/${maximum}`;
    };

    const update = (nextState) => {
        state = nextState;
        rechargeEndsAt = Number(nextState && nextState.RechargeRemaining) > 0
            ? Date.now() + Number(nextState.RechargeRemaining)
            : 0;
        render();
    };

    window.addEventListener("message", (event) => {
        if (!event.data) return;

        if (event.data.Action === "Body") {
            hudVisible = Boolean(event.data.Payload);
            render();
        } else if (event.data.Action === "Vampire") {
            update(event.data.Payload);
        }
    });

    setInterval(render, 250);
})();
