function formatCurrency(value) {
    return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
        minimumFractionDigits: 2
    }).format(value);
}

function formatNumber(value) {
    if (value >= 1000000) {
        return (value / 1000000).toFixed(1) + 'M';
    } else if (value >= 1000) {
        return (value / 1000).toFixed(1) + 'K';
    }
    return value.toString();
}

function updatePlayerInfo(data) {
    const nameElem = document.querySelector('.user-details h2');
    if (nameElem) nameElem.textContent = data.name || 'Jogador';
}

function updateJobCount(count) {
    const totalJobsElem = document.getElementById('total-jobs');
    if (totalJobsElem) totalJobsElem.textContent = count || 0;

    const jobCountElem = document.getElementById('job-count');
    if (jobCountElem) jobCountElem.textContent = `${count || 0} vagas`;
}

function renderJobs(jobs) {
    if (!jobs || jobs.length === 0) {
        renderEmptyState();
        return;
    }
    const container = document.getElementById('jobs-grid');
    if (!container) return;
    container.innerHTML = '';
    jobs.forEach(job => {
        const percentage = job.maxXp > 0 ? ((job.xp / job.maxXp) * 100).toFixed(1) : 0;

        const jobCard = `
            <div class="job-card" onclick="selectJob('${job.id}')">
                <div class="job-card-header">
                    <div class="job-icon"><i class="fas fa-solid fa-briefcase"></i></div>
                    <div class="job-level">Nível ${job.level || 1}</div>
                </div>
                <h4 class="job-title">${job.name}</h4>
                <p class="job-description">${job.description || 'Trabalho disponível'}</p>

                <div class="progress-section">
                    <div class="progress-header">
                        <span class="progress-label">Progresso</span>
                        <span class="progress-value">${formatNumber(job.xp || 0)}/${formatNumber(job.maxXp || 0)}</span>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${percentage}%"></div>
                    </div>
                </div>

                <div class="job-info">
                    <div class="info-row">
                        <span class="info-label">Pagamento por Tarefa</span>
                        <span class="info-value payment">${formatCurrency(job.payment || 0)}</span>
                    </div>
                </div>

                <div class="job-footer">
                    <span>Clique para ingressar</span>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="9 18 15 12 9 6"></polyline>
                    </svg>
                </div>
            </div>
        `;
        container.insertAdjacentHTML('beforeend', jobCard);
    });
    updateJobCount(jobs.length);
}

function renderEmptyState() {
    const container = document.getElementById('jobs-grid');
    if (!container) return;
    container.innerHTML = `
        <div class="empty-state">
            <p>Nenhum emprego disponível no momento.</p>
        </div>
    `;
    updateJobCount(0);
}

function selectJob(jobId) {
    fetch(`https://${GetParentResourceName()}/selectJob`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jobId: jobId })
    }).catch(err => console.log('Erro ao selecionar emprego:', err));
}

function closeMenu() {
    document.body.style.display = 'none';
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(err => console.log('Erro ao fechar UI:', err));
}

window.addEventListener('message', function(event) {
    const item = event.data;
    if (item.action === "toggle") {
        document.body.style.display = item.show ? 'block' : 'none';
    }
    if (item.action === "update") {
        if (item.data && item.data.name) {
            updatePlayerInfo(item.data);
        }
        if (item.data && item.data.jobs) {
            renderJobs(item.data.jobs);
        }
    }
});

document.addEventListener('DOMContentLoaded', function() {
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeMenu();
        }
    });
    renderEmptyState();
});
