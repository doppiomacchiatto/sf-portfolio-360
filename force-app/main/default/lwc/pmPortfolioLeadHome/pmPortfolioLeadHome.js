import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import getMyPrograms from '@salesforce/apex/PmDashboardController.getMyPrograms';
import getMyTasks from '@salesforce/apex/PmDashboardController.getMyTasks';
import getOpenRisks from '@salesforce/apex/PmDashboardController.getOpenRisks';

const PROGRAM_COLUMNS = [
    {
        label: 'Program',
        fieldName: 'programUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' }
    },
    { label: 'Status', fieldName: 'status' },
    { label: 'Last Updated', fieldName: 'lastUpdated', type: 'date' }
];

const TASK_COLUMNS = [
    {
        label: 'Task',
        fieldName: 'taskUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'subject' }, target: '_self' }
    },
    {
        label: 'Status',
        fieldName: 'status',
        editable: true
    },
    {
        label: 'Priority',
        fieldName: 'priority',
        editable: true
    },
    {
        label: 'Due',
        fieldName: 'dueDate',
        type: 'date',
        editable: true
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Edit', name: 'edit' }]
        }
    }
];

const RISK_COLUMNS = [
    {
        label: 'Case',
        fieldName: 'caseUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'caseNumber' }, target: '_self' }
    },
    { label: 'Subject', fieldName: 'subject' },
    { label: 'Priority', fieldName: 'priority' },
    { label: 'Status', fieldName: 'status' }
];

const TASK_FILTERS = {
    ALL_OPEN: 'ALL_OPEN',
    OVERDUE: 'OVERDUE',
    HIGH_PRIORITY: 'HIGH_PRIORITY'
};

export default class PmPortfolioLeadHome extends NavigationMixin(LightningElement) {
    programColumns = PROGRAM_COLUMNS;
    taskColumns = TASK_COLUMNS;
    riskColumns = RISK_COLUMNS;

    programs = [];
    allTasks = [];
    risks = [];
    draftValues = [];
    selectedTaskFilter = TASK_FILTERS.ALL_OPEN;
    wiredTasksResult;

    @wire(getMyPrograms)
    wiredPrograms({ data }) {
        if (data) {
            this.programs = data.map((row) => ({
                ...row,
                programUrl: `/lightning/r/Program__c/${row.id}/view`
            }));
        }
    }

    @wire(getMyTasks)
    wiredTasks(result) {
        this.wiredTasksResult = result;
        const { data } = result;
        if (data) {
            this.allTasks = data.map((row) => ({
                ...row,
                taskUrl: `/lightning/r/Task/${row.id}/view`
            }));
        }
    }

    @wire(getOpenRisks)
    wiredRisks({ data }) {
        if (data) {
            this.risks = data.map((row) => ({
                ...row,
                caseUrl: `/lightning/r/Case/${row.id}/view`
            }));
        }
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task',
                actionName: 'new'
            }
        });
    }

    handleTaskRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.id,
                    objectApiName: 'Task',
                    actionName: 'edit'
                }
            });
        }
    }

    async handleTaskSave(event) {
        const records = event.detail.draftValues.map((draft) => ({
            fields: {
                Id: draft.id,
                Status: draft.status,
                Priority: draft.priority,
                ActivityDate: draft.dueDate
            }
        }));

        try {
            await Promise.all(records.map((record) => updateRecord(record)));
            this.draftValues = [];
            await refreshApex(this.wiredTasksResult);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Tasks updated',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating tasks',
                    message: error?.body?.message || 'Unknown error',
                    variant: 'error'
                })
            );
        }
    }

    get isAllOpenFilter() {
        return this.selectedTaskFilter === TASK_FILTERS.ALL_OPEN;
    }

    get isOverdueFilter() {
        return this.selectedTaskFilter === TASK_FILTERS.OVERDUE;
    }

    get isHighPriorityFilter() {
        return this.selectedTaskFilter === TASK_FILTERS.HIGH_PRIORITY;
    }

    get allOpenFilterVariant() {
        return this.isAllOpenFilter ? 'brand' : 'neutral';
    }

    get overdueFilterVariant() {
        return this.isOverdueFilter ? 'brand' : 'neutral';
    }

    get highPriorityFilterVariant() {
        return this.isHighPriorityFilter ? 'brand' : 'neutral';
    }

    get filteredTasks() {
        if (this.isOverdueFilter) {
            const today = new Date();
            const todayAtMidnight = new Date(today.getFullYear(), today.getMonth(), today.getDate());
            return this.allTasks.filter((task) => {
                if (!task.dueDate) {
                    return false;
                }
                return new Date(task.dueDate) < todayAtMidnight;
            });
        }

        if (this.isHighPriorityFilter) {
            return this.allTasks.filter((task) => task.priority === 'High');
        }

        return this.allTasks;
    }

    handleTaskFilterChange(event) {
        this.selectedTaskFilter = event.target.dataset.filter;
        this.draftValues = [];
    }
}
