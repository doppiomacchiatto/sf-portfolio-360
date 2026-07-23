import { LightningElement, api, wire } from 'lwc';
import getKpiData from '@salesforce/apex/PmDashboardController.getKpiData';

export default class PmKpiScorecard extends LightningElement {
    @api title = 'KPI Scorecard';

    kpi;
    error;

    get isLoading() { return !this.kpi && !this.error; }
    get hasError()  { return !!this.error; }

    @wire(getKpiData)
    wiredKpi({ data, error }) {
        if (data)  { this.kpi = data; this.error = undefined; }
        if (error) { this.error = error.body?.message ?? 'Failed to load KPI data.'; this.kpi = undefined; }
    }
}
