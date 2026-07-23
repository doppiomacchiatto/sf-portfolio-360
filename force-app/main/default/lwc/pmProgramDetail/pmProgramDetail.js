import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import communityBasePath  from '@salesforce/community/basePath';
import CALLISTO_LOGO      from '@salesforce/resourceUrl/callistoLogo';
import CALLISTO_BANNER    from '@salesforce/resourceUrl/callistoBanner';
import getProgramDetail   from '@salesforce/apex/PmProgramDetailController.getProgramDetail';
import getProgramRelated  from '@salesforce/apex/PmProgramDetailController.getProgramRelated';

const STATUS_CLASS = {
    'Ideation':       'sp-ideation',
    'Validated Need': 'sp-ideation',
    'Funded':         'sp-funded',
    'Awarded':        'sp-awarded',
    'Prototype':      'sp-prototype',
    'Demo Complete':  'sp-demo',
    'Transitioning':  'sp-transitioning',
    'Operational':    'sp-operational',
};

export default class PmProgramDetail extends NavigationMixin(LightningElement) {
    @api recordId;

    program;
    related;
    error;

    @wire(getProgramDetail, { recordId: '$recordId' })
    wiredDetail({ data, error }) {
        if (data)  { this.program = data; }
        else if (error) { this.error = error?.body?.message || 'Failed to load program.'; }
    }

    @wire(getProgramRelated, { recordId: '$recordId' })
    wiredRelated({ data, error }) {
        if (data)  { this.related = data; }
        else if (error) { this.error = this.error || error?.body?.message || 'Failed to load program details.'; }
    }

    // ── Hero ───────────────────────────────────────────────────────

    get resolvedLogoUrl() { return CALLISTO_LOGO; }

    get heroStyle() {
        return `background-image:linear-gradient(90deg,rgba(6,13,26,.88) 0%,rgba(6,13,26,.52) 55%,rgba(6,13,26,.2) 100%),url('${CALLISTO_BANNER}');background-size:cover;background-position:center;`;
    }

    get programName()    { return this.program?.name    || '—'; }
    get programStatus()  { return this.program?.status  || '—'; }
    get fundAllocation() { return this.program?.fundAllocation  || '—'; }
    get programBalance() { return this.program?.programBalance  || '—'; }

    get statusPillClass() {
        return 'status-pill ' + (STATUS_CLASS[this.program?.status] || 'sp-ideation');
    }

    // ── Investment Profile ─────────────────────────────────────────

    get experimentCadence() { return this.program?.experimentCadence ?? '—'; }
    get engagementCount()   { return this.program?.engagementCount   ?? 0; }

    // ── Operational Status ─────────────────────────────────────────

    get operationalIndex()    { return this.program?.operationalIndex    ?? '—'; }
    get operationalOutcomes() { return this.program?.operationalOutcomes || null; }
    get transitionedLabel()   { return this.program?.isTransitioned ? 'Yes' : 'No'; }
    get transitionedClass()   { return this.program?.isTransitioned ? 'badge ok' : 'badge muted'; }
    get transitionOutcome()   { return this.program?.transitionOutcome   || '—'; }

    get opsGaugePath() { return this._gaugePath(this.program?.operationalIndex, 100); }
    get opsGaugeStroke() {
        const v = this.program?.operationalIndex;
        if (v == null) return '#9ca3af';
        if (v >= 75) return '#16a34a';
        if (v >= 50) return '#d97706';
        return '#dc2626';
    }
    get opsGaugeStyle() {
        return `fill:none;stroke:${this.opsGaugeStroke};stroke-width:16;stroke-linecap:round`;
    }

    // ── Timeline ───────────────────────────────────────────────────

    get milestones() {
        const p = this.program;
        if (!p) return [];
        const ms = [
            { key: 'mvd', label: 'Mission Need Validated', date: this._fmtDate(p.missionNeedValidatedDate), done: !!p.missionNeedValidatedDate },
            { key: 'fsd', label: 'Funding Start',          date: this._fmtDate(p.fundingStartDate),         done: !!p.fundingStartDate },
            { key: 'awd', label: 'Award',                  date: this._fmtDate(p.awardDate),                done: !!p.awardDate },
            { key: 'prd', label: 'First Prototype',        date: this._fmtDate(p.firstPrototypeDate),       done: !!p.firstPrototypeDate },
            { key: 'dmo', label: 'Successful Demo',        date: this._fmtDate(p.successfulDemoDate),       done: !!p.successfulDemoDate },
            { key: 'miu', label: 'Mission Use',            date: this._fmtDate(p.missionUseDate),           done: !!p.missionUseDate },
        ];
        return ms.map(m => ({ ...m, itemClass: m.done ? 'tl-item tl-done' : 'tl-item' }));
    }

    get timeMissionToFunded()  { return this.program?.timeMissionToFundedDays       ?? '—'; }
    get timeAwardToPrototype() { return this.program?.timeAwardToPrototypeMonths ?? '—'; }
    get timeDemoToMissionUse() { return this.program?.timeDemoToMissionUseMonths  ?? '—'; }

    // ── Technical Maturity ─────────────────────────────────────────

    get currentTrl()  { return this.related?.currentTrl  ?? '—'; }
    get previousTrl() { return this.related?.previousTrl ?? '—'; }
    get trlGain()     { return this.related?.trlGain     ?? '—'; }
    get trlDate()     { return this._fmtDate(this.related?.trlDate); }
    get trlElement()  { return this.related?.trlElement  || null; }
    get trlBarStyle() { return this._rlBarStyle(this.related?.currentTrl, 9); }
    get trlLevelPips() { return this._rlPips(this.related?.currentTrl, 9); }

    get currentMrl()  { return this.related?.currentMrl  ?? '—'; }
    get previousMrl() { return this.related?.previousMrl ?? '—'; }
    get mrlGain()     { return this.related?.mrlGain     ?? '—'; }
    get mrlDate()     { return this._fmtDate(this.related?.mrlDate); }
    get mrlBarStyle() { return this._rlBarStyle(this.related?.currentMrl, 9); }
    get mrlLevelPips() { return this._rlPips(this.related?.currentMrl, 9); }

    get examPassRate()      { return this.related?.examPassRate      ?? '—'; }
    get examsAdministered() { return this.related?.examsAdministered ?? '—'; }
    get examsPass()         { return this.related?.examsPass         ?? '—'; }
    get examDate()          { return this._fmtDate(this.related?.examDate); }
    get examType()          { return this.related?.examType          || null; }
    get examGaugePath()     { return this._gaugePath(this.related?.examPassRate, 100); }

    // ── Transition ─────────────────────────────────────────────────

    get hasTransition()         { return this.related?.hasTransition      === true; }
    get transitionType()        { return this.related?.transitionType     || '—'; }
    get transitionOwner()       { return this.related?.transitionOwner    || '—'; }
    get testVenue()             { return this.related?.testVenue          || '—'; }
    get transitionSignedLabel()     { return this.related?.transitionSigned    ? 'Yes' : 'No'; }
    get transitionCommittedLabel()  { return this.related?.transitionCommitted ? 'Yes' : 'No'; }
    get fundedReceiverLabel()       { return this.related?.fundedReceiverPath  ? 'Yes' : 'No'; }
    get integrationPlanLabel()      { return this.related?.integrationPlan     ? 'Yes' : 'No'; }
    get transitionSignedClass()     { return this.related?.transitionSigned    ? 'badge ok'    : 'badge muted'; }
    get transitionCommittedClass()  { return this.related?.transitionCommitted ? 'badge ok'    : 'badge muted'; }
    get fundedReceiverClass()       { return this.related?.fundedReceiverPath  ? 'badge ok'    : 'badge muted'; }
    get integrationPlanClass()      { return this.related?.integrationPlan     ? 'badge ok'    : 'badge muted'; }

    // ── Evidence ───────────────────────────────────────────────────

    get evidenceContinue() { return this.related?.evidenceContinue ?? 0; }
    get evidencePivot()    { return this.related?.evidencePivot    ?? 0; }
    get evidenceTotal()    { return this.evidenceContinue + this.evidencePivot; }
    get evidenceAvgDays()  { return this.related?.evidenceAvgDays  ?? '—'; }

    // ── Engagements ────────────────────────────────────────────────

    get engagementRows() {
        return (this.related?.engagements || []).map(e => ({
            ...e,
            barStyle: `width:${e.pct}%`,
        }));
    }
    get hasEngagements() { return this.engagementRows.length > 0; }

    // ── Navigation ─────────────────────────────────────────────────

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: communityBasePath + '/' }
        });
    }

    // ── Helpers ────────────────────────────────────────────────────

    _fmtDate(dateStr) {
        if (!dateStr) return '—';
        const d = new Date(dateStr + 'T00:00:00');
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    _rlBarStyle(val, max) {
        if (val == null) return 'width:0%;background:#9ca3af';
        const pct   = Math.min(Math.round(val / max * 100), 100);
        const color = val >= 8 ? '#16a34a' : val >= 6 ? '#3498db' : val >= 4 ? '#d97706' : '#dc2626';
        return `width:${pct}%;background:${color}`;
    }

    _rlPips(val, max) {
        return Array.from({ length: max }, (_, i) => {
            const filled = val != null && (i + 1) <= val;
            return { key: i + 1, filled, pipClass: filled ? 'pip pip-on' : 'pip pip-off' };
        });
    }

    _gaugePath(value, max) {
        if (value == null) return '';
        const pct      = Math.min(value / max, 1);
        const endAngle = Math.PI - pct * Math.PI;
        const cx = 90, cy = 80, r = 70;
        const x = (cx + r * Math.cos(endAngle)).toFixed(1);
        const y = (cy - r * Math.sin(endAngle)).toFixed(1);
        return `M 20 80 A 70 70 0 ${pct > 0.5 ? 1 : 0} 1 ${x} ${y}`;
    }
}
