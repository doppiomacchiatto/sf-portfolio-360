import { LightningElement, api } from 'lwc';

export default class PmExecNewsEvents extends LightningElement {
    @api sectionTitle = 'Portfolio Events';
    @api eventTitle = 'Sign up for Beta Testing for Titan';
    @api eventDescription = 'Join the Titan beta cohort to validate usability, mission relevance, and operational readiness with early access.';
    @api buttonLabel = 'Sign Up';
    @api signupUrl = '/titanx/s/';
}
