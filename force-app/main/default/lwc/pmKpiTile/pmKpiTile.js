import { LightningElement, api } from 'lwc';

export default class PmKpiTile extends LightningElement {
    @api label   = '';
    @api value;
    @api suffix  = '';
    @api kpiNum  = '';

    get hasValue() { return this.value !== null && this.value !== undefined; }
}
