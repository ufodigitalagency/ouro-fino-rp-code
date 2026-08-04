(() => {
    const resourceName = typeof GetParentResourceName === "function"
        ? GetParentResourceName()
        : "nation_concessionaria";
    const closeButton = document.getElementById("of-conce-close");
    let visible = false;

    function normalizeNuiUrl(url) {
        if (typeof url !== "string") return url;

        const legacyPrefix = `http://${resourceName}/`;
        if (url.toLowerCase().startsWith(legacyPrefix.toLowerCase())) {
            return `https://${resourceName}/${url.slice(legacyPrefix.length)}`;
        }

        return url;
    }

    function installNuiHttpsBridge() {
        const jq = window.jQuery || window.$;

        if (!jq) {
            window.setTimeout(installNuiHttpsBridge, 50);
            return;
        }

        if (jq.__ofNuiHttpsBridgeInstalled) return;
        jq.__ofNuiHttpsBridgeInstalled = true;

        if (typeof jq.ajaxPrefilter === "function") {
            jq.ajaxPrefilter((options, originalOptions) => {
                options.url = normalizeNuiUrl(options.url);

                if (originalOptions) {
                    originalOptions.url = normalizeNuiUrl(originalOptions.url);
                }
            });
        }

        if (typeof jq.post === "function") {
            const originalPost = jq.post;

            jq.post = function (url, ...args) {
                const normalizedUrl = normalizeNuiUrl(url);
                const request = originalPost.call(this, normalizedUrl, ...args);

                if (request && typeof request.fail === "function") {
                    request.fail((_xhr, status, error) => {
                        console.error(
                            "[nation_concessionaria] Falha no callback NUI:",
                            normalizedUrl,
                            status,
                            error
                        );

                        if (typeof window.fail === "function") {
                            window.fail("Falha de comunicacao ao processar a solicitacao.");
                        }

                        if (typeof window.closePopUp === "function") {
                            window.setTimeout(() => window.closePopUp(), 2500);
                        }
                    });
                }

                return request;
            };
        }

        console.info("[nation_concessionaria] NUI HTTPS bridge ativo.");
    }

    installNuiHttpsBridge();

    function isVisible(element) {
        if (!element) return false;
        const styles = window.getComputedStyle(element);
        return styles.display !== "none" && styles.visibility !== "hidden" && element.offsetParent !== null;
    }

    function hasOpenPanel() {
        return isVisible(document.querySelector(".menu-container")) ||
            isVisible(document.querySelector(".menu-admin-container"));
    }

    function setVisible(state) {
        visible = !!state;
        if (closeButton) {
            closeButton.classList.toggle("is-visible", visible);
        }
    }

    function closePanel() {
        fetch(`https://${resourceName}/close`, {
            method: "POST",
            headers: {"Content-Type": "application/json; charset=UTF-8"},
            body: JSON.stringify({source: "close-fix"})
        }).catch(() => {});
        setVisible(false);
    }

    window.addEventListener("message", (event) => {
        const action = event.data && event.data.action;

        if (action === "show" || action === "showAdmin") {
            setVisible(true);
        }

        if (action === "hide" || action === "hideAdmin") {
            setVisible(false);
        }

        setTimeout(() => setVisible(hasOpenPanel()), 60);
    });

    window.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && visible) {
            event.preventDefault();
            closePanel();
        }
    });

    document.addEventListener("click", (event) => {
        if (!visible) return;

        if (event.target === closeButton) {
            event.preventDefault();
            closePanel();
            return;
        }

        if (!event.target.closest(".menu-container, .menu-admin-container")) {
            closePanel();
        }
    });

    window.setInterval(() => setVisible(hasOpenPanel()), 500);
})();
