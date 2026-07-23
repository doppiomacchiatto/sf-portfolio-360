import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import communityBasePath from '@salesforce/community/basePath';
import getKpiData        from '@salesforce/apex/PmDashboardController.getKpiData';
import getPipelineData   from '@salesforce/apex/PmDashboardController.getPipelineData';
import getMyPrograms     from '@salesforce/apex/PmDashboardController.getMyPrograms';
import getPortfolioMix   from '@salesforce/apex/PmDashboardController.getPortfolioMix';
import getReadinessData  from '@salesforce/apex/PmDashboardController.getReadinessData';
import getEvidenceSummary from '@salesforce/apex/PmDashboardController.getEvidenceSummary';
import getUpeBreakdown   from '@salesforce/apex/PmDashboardController.getUpeBreakdown';
import getTransitions    from '@salesforce/apex/PmDashboardController.getTransitions';
import CALLISTO_LOGO     from '@salesforce/resourceUrl/callistoLogo';
import CALLISTO_BANNER   from '@salesforce/resourceUrl/callistoBanner';

const FUND_COLORS    = ['#3498db','#e67e22','#e74c3c','#27ae60','#9b59b6','#1abc9c'];
const BALANCE_COLORS = ['#3498db','#e67e22','#2c3e50','#27ae60','#5dade2','#f39c12'];

const STATUS_CLASS = {
    'Ideation':        'sp-ideation',
    'Validated Need':  'sp-ideation',
    'Funded':          'sp-funded',
    'Awarded':         'sp-awarded',
    'Prototype':       'sp-prototype',
    'Demo Complete':   'sp-demo',
    'Transitioning':   'sp-transitioning',
    'Operational':     'sp-operational',
};

const PHASE_STATUS_MAP = {
    Ideation: ['Ideation', 'Validated Need'],
    Funded: ['Funded'],
    Awarded: ['Awarded'],
    Prototype: ['Prototype'],
    'Demo Complete': ['Demo Complete'],
    Transitioning: ['Transitioning'],
    Operational: ['Operational']
};

export default class PmExecutiveExperienceHome extends NavigationMixin(LightningElement) {
    @api heroTitle    = 'R&D Portfolio Executive Dashboard';
    @api heroSubtitle = 'All active programs — KPI-driven executive view across investment, speed, technical maturity, portfolio health, transition, and operational outcomes.';
    @api logoUrl;
    @api bannerUrl;

    kpi; pipeline = []; programs = []; portfolioMix;
    readiness = []; evidence; upe = []; transitions = [];
    error;
    uiState = {
        scope: 'ALL',
        phase: 'ALL',
        watchSeverity: 'ALL',
        trendWindow: 'CURRENT',
        compareMode: 'OFF',
        drill: null
    };
    deepDive;

    // ── Wire handlers ────────────────────────────────────────────

    @wire(getKpiData)
    wiredKpi({ data, error }) {
        if (data) { this.kpi = data; } else if (error) { this._setError(error); }
    }

    @wire(getPipelineData)
    wiredPipeline({ data, error }) {
        if (data) { this.pipeline = data; } else if (error) { this._setError(error); }
    }

    @wire(getMyPrograms)
    wiredPrograms({ data, error }) {
        if (data) { this.programs = data; } else if (error) { this._setError(error); }
    }

    @wire(getPortfolioMix)
    wiredMix({ data, error }) {
        if (data) { this.portfolioMix = data; } else if (error) { this._setError(error); }
    }

    @wire(getReadinessData)
    wiredReadiness({ data, error }) {
        if (data) { this.readiness = data; } else if (error) { this._setError(error); }
    }

    @wire(getEvidenceSummary)
    wiredEvidence({ data, error }) {
        if (data) { this.evidence = data; } else if (error) { this._setError(error); }
    }

    @wire(getUpeBreakdown)
    wiredUpe({ data, error }) {
        if (data) { this.upe = data; } else if (error) { this._setError(error); }
    }

    @wire(getTransitions)
    wiredTransitions({ data, error }) {
        if (data) { this.transitions = data; } else if (error) { this._setError(error); }
    }

    _setError(err) {
        this.error = err?.body?.message || 'Failed to load dashboard data.';
    }

    // ── Hero ─────────────────────────────────────────────────────

    get resolvedLogoUrl()   { return this.logoUrl   || CALLISTO_LOGO; }
    get resolvedBannerUrl() { return this.bannerUrl || CALLISTO_BANNER; }

    get heroStyle() {
        return `background-image: linear-gradient(90deg,rgba(6,13,26,.85) 0%,rgba(6,13,26,.48) 55%,rgba(6,13,26,.2) 100%),url('${this.resolvedBannerUrl}');background-size:cover;background-position:center;`;
    }

    get totalPrograms()       { return this.kpi?.totalPrograms       ?? '—'; }
    get totalEngagements()    { return this.kpi?.totalEngagements     ?? '—'; }
    get programsTransitioned(){ return this.kpi?.programsTransitioned ?? '—'; }
    get transitionsCommitted(){ return this.kpi?.transitionsCommitted ?? '—'; }
    get activeProgramCount()  { return this.scopedPrograms.length; }
    get scopeLabel() {
        return this.uiState.scope === 'ACTIVE' ? 'Active Programs'
            : this.uiState.scope === 'TRANSITION' ? 'Transition Focus'
            : 'All Programs';
    }

    get isAllScope() {
        return this.uiState.scope === 'ALL';
    }

    get isActiveScope() {
        return this.uiState.scope === 'ACTIVE';
    }

    get allProgramsChipClass() {
        return `chip ${this.isAllScope ? 'active' : ''}`.trim();
    }

    get activeProgramsChipClass() {
        return `chip ${this.isActiveScope ? 'active' : ''}`.trim();
    }

    get transitionProgramsChipClass() {
        return `chip ${this.uiState.scope === 'TRANSITION' ? 'active' : ''}`.trim();
    }

    get watchAllClass() {
        return `chip ${this.uiState.watchSeverity === 'ALL' ? 'active' : ''}`.trim();
    }

    get watchHighClass() {
        return `chip ${this.uiState.watchSeverity === 'High' ? 'active' : ''}`.trim();
    }

    get watchMedClass() {
        return `chip ${this.uiState.watchSeverity === 'Med' ? 'active' : ''}`.trim();
    }

    get watchLowClass() {
        return `chip ${this.uiState.watchSeverity === 'Low' ? 'active' : ''}`.trim();
    }

    get activeProgramsStatClass() {
        return `hero-stat ${this.isActiveScope ? 'hero-stat-active' : ''}`.trim();
    }

    get transitionedProgramsStatClass() {
        return `hero-stat ${this.uiState.scope === 'TRANSITION' ? 'hero-stat-active' : ''}`.trim();
    }

    get hasDrill() {
        return !!this.uiState.drill;
    }

    get drillLabel() {
        return this.uiState.drill?.label;
    }

    get scopedPrograms() {
        const rows = this.programs || [];
        let filtered = rows;
        if (this.uiState.scope === 'ACTIVE') {
            filtered = filtered.filter((p) => p.status !== 'Closed');
        }
        if (this.uiState.scope === 'TRANSITION') {
            filtered = filtered.filter((p) => ['Transitioning', 'Operational'].includes(p.status));
        }
        if (this.uiState.phase !== 'ALL') {
            const statuses = PHASE_STATUS_MAP[this.uiState.phase] || [this.uiState.phase];
            filtered = filtered.filter((p) => statuses.includes(p.status));
        }
        if (this.uiState.drill?.type === 'WATCH' && Array.isArray(this.uiState.drill.programs)) {
            const drillSet = new Set(this.uiState.drill.programs);
            filtered = filtered.filter((p) => drillSet.has(p.name));
        }
        return filtered;
    }

    get scopedTransitions() {
        const included = new Set(this.scopedPrograms.map((p) => p.name));
        return (this.transitions || []).filter((t) => included.has(t.programName));
    }

    get scopedPipeline() {
        const phases = this.pipeline || [];
        return phases.map((phase) => {
            const statuses = PHASE_STATUS_MAP[phase.label] || [phase.label];
            const count = this.scopedPrograms.filter((p) => statuses.includes(p.status)).length;
            return { ...phase, count };
        });
    }

    get scopedProgramsTransitioned() {
        return this.scopedPrograms.filter((p) => ['Transitioning', 'Operational'].includes(p.status)).length;
    }

    get scopedTransitionsCommitted() {
        return this.scopedTransitions.filter((t) => t.committed).length;
    }

    get hasPrograms() {
        return this.programRows.length > 0;
    }

    setUiState(patch) {
        this.uiState = { ...this.uiState, ...patch };
    }

    handleFilterAction(event) {
        const { filterType, filterValue } = event.currentTarget.dataset;
        if (filterType === 'scope') {
            this.setUiState({ scope: filterValue, drill: null });
            return;
        }
        if (filterType === 'phase') {
            this.setUiState({
                phase: this.uiState.phase === filterValue ? 'ALL' : filterValue,
                drill: { type: 'PHASE', label: `Phase: ${filterValue}` }
            });
            return;
        }
        if (filterType === 'watchSeverity') {
            this.setUiState({ watchSeverity: filterValue });
            return;
        }
        if (filterType === 'trendWindow') {
            this.setUiState({ trendWindow: filterValue });
            return;
        }
        if (filterType === 'compareMode') {
            const next = this.uiState.compareMode === 'OFF' ? 'YOY' : 'OFF';
            this.setUiState({ compareMode: next });
        }
    }

    handleResetFilters() {
        this.uiState = {
            scope: 'ALL',
            phase: 'ALL',
            watchSeverity: 'ALL',
            trendWindow: 'CURRENT',
            compareMode: 'OFF',
            drill: null
        };
        this.deepDive = null;
    }

    clearDrill() {
        this.setUiState({ phase: 'ALL', drill: null });
    }

    openKpiDrill(event) {
        const { drill, title } = event.currentTarget.dataset;
        const rows = this._getDeepDiveRows(drill);
        this.deepDive = {
            title: title || 'KPI Detail',
            metric: drill,
            severity: 'info',
            severityClass: 'deep-severity-info',
            rows
        };
        this.setUiState({ drill: { type: 'KPI', label: title || 'KPI Detail' } });
        this._focusDeepDive();
    }

    closeDeepDive() {
        this.deepDive = null;
    }

    openWatchDrill(event) {
        const watchKey = event.currentTarget.dataset.watchKey;
        const impacted = this._impactedProgramsForWatch(watchKey);
        const watch = this.openWatches.find((w) => w.key === watchKey);
        const severity = (watch?.severity || 'Med').toLowerCase();
        this.deepDive = {
            title: 'Impacted Programs',
            metric: watchKey,
            severity,
            severityClass: `deep-severity-${severity}`,
            rows: impacted.map((p) => this._toDetailRow(p, watch?.kpiLabel || 'Watch Impact', watch?.detail || 'Program impacted by active watch'))
        };
        this.setUiState({
            drill: {
                type: 'WATCH',
                label: `Watch: ${watchKey}`,
                programs: impacted.map((p) => p.name)
            }
        });
        this._focusDeepDive();
    }

    _impactedProgramsForWatch(watchKey) {
        const list = this.programs || [];
        if (watchKey === 'kpi4') {
            return list.filter((p) => ['Awarded', 'Prototype'].includes(p.status));
        }
        if (watchKey === 'kpi5') {
            return list.filter((p) => ['Demo Complete', 'Transitioning'].includes(p.status));
        }
        if (watchKey === 'kpi11') {
            const tMap = new Set((this.transitions || []).filter((t) => !t.committed).map((t) => t.programName));
            return list.filter((p) => tMap.has(p.name));
        }
        return list;
    }

    _getDeepDiveRows(drill) {
        if (drill === 'speed') {
            return [
                ...this.scopedPrograms.slice(0, 6).map((p) =>
                    this._toDetailRow(
                        p,
                        'Speed and Acceleration',
                        `Mission→Funded ${this.kpi3}d · Award→Prototype ${this.kpi4}mo · Demo→Use ${this.kpi5}mo`
                    )
                )
            ];
        }
        if (drill === 'transition') {
            const byName = new Map((this.programs || []).map((p) => [p.name, p]));
            return this.scopedTransitions.map((t) => {
                const p = byName.get(t.programName);
                return this._toDetailRow(
                    p,
                    'Transition Pipeline',
                    `${t.transitionType || 'Transition'} · Signed: ${t.signed ? 'Yes' : 'No'} · Committed: ${t.committed ? 'Yes' : 'No'}`
                );
            });
        }
        return this.programRows.map((p) => this._toDetailRow(p, 'Program Overview', `Current status: ${p.status}`));
    }

    _toDetailRow(program, contextLabel, detailText) {
        const name = program?.name || 'Unknown Program';
        const status = program?.status || 'Unknown';
        const id = program?.id || null;
        return {
            key: id || `${name}-${contextLabel}`,
            name,
            status,
            contextLabel,
            detailText,
            programId: id,
            hasRecordUrl: !!id
        };
    }

    handleGoToProgram(event) {
        const recordId = event.currentTarget.dataset.recordId;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${communityBasePath}/program/${recordId}` }
        });
    }

    _focusDeepDive() {
        requestAnimationFrame(() => {
            const panel = this.template?.querySelector('.deep-dive');
            if (panel) {
                panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    }

    // ── Programs at a Glance ─────────────────────────────────────

    get programRows() {
        return this.scopedPrograms.map(p => ({
            ...p,
            pillClass: 'status-pill ' + (STATUS_CLASS[p.status] || 'sp-ideation'),
        }));
    }

    get fundAllocationItems() {
        return (this.portfolioMix?.fundAllocation || []).map((item, i) => ({
            ...item,
            segStyle: `flex:${Math.max(item.pct, 5)};background:${FUND_COLORS[i % FUND_COLORS.length]}`,
            dotStyle: `background:${FUND_COLORS[i % FUND_COLORS.length]}`,
        }));
    }

    get balanceItems() {
        return (this.portfolioMix?.portfolioBalance || []).map((item, i) => ({
            ...item,
            segStyle: `flex:${Math.max(item.pct, 5)};background:${BALANCE_COLORS[i % BALANCE_COLORS.length]}`,
            dotStyle: `background:${BALANCE_COLORS[i % BALANCE_COLORS.length]}`,
        }));
    }

    // ── Speed (KPIs 3–5) ─────────────────────────────────────────

    get kpi3() { return this._trendAdjusted(this.kpi?.avgMissionToFundedDays, 15, 'down'); }
    get kpi4() { return this._trendAdjusted(this.kpi?.avgAwardToPrototypeMonths, 1.4, 'down'); }
    get kpi5() { return this._trendAdjusted(this.kpi?.avgDemoToMissionUseMonths, 1.2, 'down'); }

    get isTrendCurrent() {
        return this.uiState.trendWindow === 'CURRENT';
    }

    get currentTrendClass() {
        return `chip ${this.isTrendCurrent ? 'active' : ''}`.trim();
    }

    get baselineTrendClass() {
        return `chip ${!this.isTrendCurrent ? 'active' : ''}`.trim();
    }

    get compareModeClass() {
        return `chip ${this.uiState.compareMode !== 'OFF' ? 'active' : ''}`.trim();
    }

    get trendWindowLabel() {
        return this.uiState.trendWindow === 'CURRENT' ? 'Current Window' : 'Baseline Window';
    }

    get kpi3Badge() { return this._badge(this.kpi?.avgMissionToFundedDays,    v => v <= 180, 'On Target', 'Watch — target < 180 days'); }
    get kpi4Badge() { return this._badge(this.kpi?.avgAwardToPrototypeMonths, v => v <= 12,  'On Target', 'Watch — target ≤ 12 months'); }
    get kpi5Badge() { return this._badge(this.kpi?.avgDemoToMissionUseMonths, v => v <= 12,  'On Target', 'Watch — target ≤ 12 months'); }

    // ── Technical Maturity (KPIs 6–8) ───────────────────────────

    get kpi6() { return this.kpi?.avgTrlGain ?? '—'; }
    get kpi7() { return this.kpi?.avgMrlGain ?? '—'; }
    get kpi8() { return this.kpi?.avgExamPassRate ?? '—'; }

    get kpi6Badge() { return this._badge(this.kpi?.avgTrlGain,    v => v >= 1,  'On Target', 'Watch — target ≥ 1.0 TRL gain'); }
    get kpi7Badge() { return this._badge(this.kpi?.avgMrlGain,    v => v >= 1,  'On Target', 'Watch — target ≥ 1.0 MRL gain'); }
    get kpi8Badge() { return this._badge(this.kpi?.avgExamPassRate, v => v >= 85, 'On Target — target ≥ 85%', 'Watch — target ≥ 85%'); }

    get trlBands() {
        const rows  = this.readiness || [];
        const total = rows.length || 1;
        return [
            { key: 'e', label: 'TRL 1–3 (Early)',       min: 1, max: 3 },
            { key: 'l', label: 'TRL 4–5 (Lab)',          min: 4, max: 5 },
            { key: 'd', label: 'TRL 6–7 (Demo)',         min: 6, max: 7 },
            { key: 'o', label: 'TRL 8–9 (Operational)',  min: 8, max: 9 },
        ].map(b => {
            const count = rows.filter(r => r.trl != null && r.trl >= b.min && r.trl <= b.max).length;
            const pct   = Math.round(count / total * 100);
            const color = b.min >= 8 ? '#16a34a' : b.min >= 6 ? '#3498db' : b.min >= 4 ? '#d97706' : '#dc2626';
            return { ...b, count, barStyle: `width:${pct}%;background:${color}` };
        });
    }

    get readinessRows() {
        return (this.readiness || []).map(r => ({
            ...r,
            trlClass:   this._rlClass(r.trl),
            mrlClass:   this._rlClass(r.mrl),
            trlDisplay: r.trl ?? '—',
            mrlDisplay: r.mrl ?? '—',
        }));
    }

    _rlClass(val) {
        if (val == null) return 'rl-none';
        if (val <= 2)    return 'rl-c1';
        if (val <= 4)    return 'rl-c2';
        if (val <= 6)    return 'rl-c3';
        if (val === 7)   return 'rl-c4';
        if (val === 8)   return 'rl-c5';
        return 'rl-c6';
    }

    get kpi8GaugePath()  { return this._gaugePath(this.kpi?.avgExamPassRate,    100); }
    get kpi14GaugePath() { return this._gaugePath(this.kpi?.avgOperationalIndex, 100); }

    _gaugePath(value, max) {
        if (value == null) return '';
        const pct      = Math.min(value / max, 1);
        const endAngle = Math.PI - pct * Math.PI;
        const cx = 90, cy = 80, r = 70;
        const x = (cx + r * Math.cos(endAngle)).toFixed(1);
        const y = (cy - r * Math.sin(endAngle)).toFixed(1);
        return `M 20 80 A 70 70 0 ${pct > 0.5 ? 1 : 0} 1 ${x} ${y}`;
    }

    // ── Portfolio Health (KPIs 9–10) ─────────────────────────────

    get evidenceContinue()    { return this.evidence?.continueCount ?? 0; }
    get evidencePivot()       { return this.evidence?.pivotCount    ?? 0; }
    get evidenceTotal()       { return this.evidenceContinue + this.evidencePivot; }
    get evidenceAvgDays()     { return this.evidence?.avgDaysToDecision ?? '—'; }
    get evidenceContinuePct() { return this.evidenceTotal > 0 ? Math.round(this.evidenceContinue / this.evidenceTotal * 100) : 0; }
    get evidencePivotPct()    { return this.evidenceTotal > 0 ? Math.round(this.evidencePivot    / this.evidenceTotal * 100) : 0; }

    get upeRows() {
        return (this.upe || []).map(u => ({
            ...u,
            barStyle: `width:${u.pct}%`,
        }));
    }

    // ── Transition Pipeline (KPIs 11–13) ────────────────────────

    get kpi11Rate() {
        const t = this.scopedTransitions.length;
        return t > 0 ? Math.round(this.scopedTransitionsCommitted / t * 100) : '—';
    }
    get kpi12Rate() {
        const t = this.scopedTransitions.length;
        return t > 0 ? Math.round(this.scopedProgramsTransitioned / t * 100) : '—';
    }

    get kpi11Badge() { return this._badge(typeof this.kpi11Rate === 'number' ? this.kpi11Rate : null, v => v >= 75, 'On Target', 'Watch — target ≥ 75%'); }
    get kpi12Badge() { return this._badge(typeof this.kpi12Rate === 'number' ? this.kpi12Rate : null, v => v >= 70, 'On Target — target ≥ 70%', 'Watch — target ≥ 70%'); }

    get kpi11Total() { return this.scopedTransitions.length; }

    get transitionRows() {
        return this.scopedTransitions.map(t => ({
            ...t,
            signedCls:    t.signed    ? 'tr-yes' : 'tr-no',
            signedIcon:   t.signed    ? '✓' : '○',
            committedCls: t.committed ? 'tr-yes' : 'tr-no',
            committedIcon:t.committed ? '✓' : '○',
        }));
    }

    get transitionTypeSummary() {
        const typeMap = {};
        this.scopedTransitions.forEach(t => {
            const key = t.transitionType || 'Unknown';
            typeMap[key] = (typeMap[key] || 0) + 1;
        });
        const maxCount = Math.max(...Object.values(typeMap), 1);
        return Object.entries(typeMap).map(([label, count]) => ({
            label, count,
            barStyle: `width:${Math.round(count / maxCount * 100)}%`,
        }));
    }

    // ── Operational Outcomes (KPI 14) ────────────────────────────

    get kpi14() { return this.kpi?.avgOperationalIndex ?? '—'; }

    // ── Open Watches ─────────────────────────────────────────────

    get openWatches() {
        if (!this.kpi) return [];
        const w = [];
        const v4 = this.kpi.avgAwardToPrototypeMonths;
        if (v4 != null && v4 > 12) {
            w.push({ key: 'kpi4', kpiLabel: 'Award → Prototype', name: `Portfolio avg ${v4} months`, detail: 'All programs above 12-month target', badge: 'High', badgeCls: 'badge warn', severity: 'High' });
        }
        const nearTerm = (this.portfolioMix?.portfolioBalance || []).find(b => b.label === 'Near Term');
        if (nearTerm && nearTerm.pct > 30) {
            w.push({ key: 'kpi2', kpiLabel: 'Portfolio Balance', name: 'Near Term Concentration', detail: `${nearTerm.pct}% of programs — target ≤ 30%`, badge: 'Med', badgeCls: 'badge warn', severity: 'Med' });
        }
        const v5 = this.kpi.avgDemoToMissionUseMonths;
        if (v5 != null && v5 > 12) {
            w.push({ key: 'kpi5', kpiLabel: 'Demo → Mission Use', name: `Combined avg ${v5} months`, detail: 'Target ≤ 12 months', badge: 'Med', badgeCls: 'badge warn', severity: 'Med' });
        }
        const rate11 = typeof this.kpi11Rate === 'number' ? this.kpi11Rate : null;
        if (rate11 != null && rate11 < 75) {
            w.push({ key: 'kpi11', kpiLabel: 'Transition Commitment', name: `${rate11}% of transitions committed`, detail: 'Target ≥ 75%', badge: 'Low', badgeCls: 'badge warn', severity: 'Low' });
        }
        if (this.uiState.watchSeverity === 'ALL') {
            return w;
        }
        return w.filter((item) => item.severity === this.uiState.watchSeverity);
    }

    get hasOpenWatches()  { return this.openWatches.length > 0; }
    get openWatchCount()  { return this.openWatches.length; }

    // ── Helpers ──────────────────────────────────────────────────

    _badge(value, testFn, okText, warnText) {
        if (value == null) return null;
        return testFn(value)
            ? { text: okText,   cls: 'badge ok'   }
            : { text: warnText, cls: 'badge warn'  };
    }

    _trendAdjusted(value, delta, direction) {
        if (value == null || this.uiState.trendWindow === 'CURRENT') {
            return value ?? '—';
        }
        const signed = direction === 'down' ? -delta : delta;
        const adjusted = Number(value) + signed;
        return Math.max(0, Number(adjusted.toFixed(1)));
    }
}
