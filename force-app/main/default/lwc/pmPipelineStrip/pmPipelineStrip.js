import { LightningElement, api, wire } from 'lwc';
import getPipelineData from '@salesforce/apex/PmDashboardController.getPipelineData';

export default class PmPipelineStrip extends LightningElement {
    @api title = 'Program Pipeline';

    phases;
    error;

    get isLoading() { return !this.phases && !this.error; }
    get hasError()  { return !!this.error; }

    @wire(getPipelineData)
    wiredPipeline({ data, error }) {
        if (data)  { this.phases = data; this.error = undefined; }
        if (error) { this.error = error.body?.message ?? 'Failed to load pipeline data.'; this.phases = undefined; }
    }
}
