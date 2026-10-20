public with sharing class PmProgramDetailController {

    @AuraEnabled(cacheable=true)
    public static ProgramDetail getProgramDetail(Id recordId) {
        if (recordId == null) return null;
        pm_Program__c p = [
            SELECT Name, Program_Status__c, Fund_Allocation__c, Program_Balance__c,
                   Award_Date__c, Funding_Start_Date__c, First_Prototype_Date__c,
                   Successful_Demo_Date__c, Mission_Need_Validated_Date__c, Mission_Use_Date__c,
                   Time_Award_to_Prototype_Months__c, Time_Demo_to_MissionUse_Months__c,
                   Time_Mission_to_Funded_Days__c, Experiment_Cadence__c, Engagement_Count__c,
                   Operational_Index__c, Operational_Outcomes__c, Is_Transitioned__c, Transition_Outcome__c
            FROM pm_Program__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1
        ];
        return new ProgramDetail(p);
    }

    @AuraEnabled(cacheable=true)
    public static ProgramRelated getProgramRelated(Id recordId) {
        if (recordId == null) return null;
        ProgramRelated rel = new ProgramRelated();

        List<pm_TRL__c> trls = [
            SELECT Current_TRL__c, Previous_TRL__c, TRL_Gain__c, Assessment_Date__c,
                   Technology_Element__c
            FROM pm_TRL__c WHERE pm_Program__c = :recordId
            ORDER BY Assessment_Date__c DESC NULLS LAST LIMIT 1
        ];
        if (!trls.isEmpty()) {
            pm_TRL__c t = trls[0];
            rel.currentTrl     = t.Current_TRL__c  != null ? (Integer)t.Current_TRL__c  : null;
            rel.previousTrl    = t.Previous_TRL__c != null ? (Integer)t.Previous_TRL__c : null;
            rel.trlGain        = t.TRL_Gain__c;
            rel.trlDate        = t.Assessment_Date__c;
            rel.trlElement     = t.Technology_Element__c;
        }

        List<pm_MRL__c> mrls = [
            SELECT Current_MRL__c, Previous_MRL__c, MRL_Gain__c, Assessment_Date__c
            FROM pm_MRL__c WHERE pm_Program__c = :recordId
            ORDER BY Assessment_Date__c DESC NULLS LAST LIMIT 1
        ];
        if (!mrls.isEmpty()) {
            pm_MRL__c m = mrls[0];
            rel.currentMrl  = m.Current_MRL__c  != null ? (Integer)m.Current_MRL__c  : null;
            rel.previousMrl = m.Previous_MRL__c != null ? (Integer)m.Previous_MRL__c : null;
            rel.mrlGain     = m.MRL_Gain__c;
            rel.mrlDate     = m.Assessment_Date__c;
        }

        List<pm_Technical_Exam__c> exams = [
            SELECT Pass_Rate__c, Exams_Administered__c, Exams_Pass__c, Exam_Date__c, Exam_Type__c
            FROM pm_Technical_Exam__c WHERE pm_Program__c = :recordId
            ORDER BY Exam_Date__c DESC NULLS LAST LIMIT 1
        ];
        if (!exams.isEmpty()) {
            pm_Technical_Exam__c e = exams[0];
            rel.examPassRate      = e.Pass_Rate__c;
            rel.examsAdministered = e.Exams_Administered__c != null ? (Integer)e.Exams_Administered__c : null;
            rel.examsPass         = e.Exams_Pass__c         != null ? (Integer)e.Exams_Pass__c         : null;
            rel.examDate          = e.Exam_Date__c;
            rel.examType          = e.Exam_Type__c;
        }

        List<pm_Project_Transition__c> pts = [
            SELECT Prototype_Transition__c, Signed_Transition_Agreement__c,
                   Transition_Commitment_Complete__c, Funded_Receiver_Path__c,
                   Integration_Plan__c, Transition_Owner__c, Test_Venue__c
            FROM pm_Project_Transition__c WHERE pm_Program__c = :recordId LIMIT 1
        ];
        if (!pts.isEmpty()) {
            pm_Project_Transition__c pt = pts[0];
            rel.transitionType      = pt.Prototype_Transition__c;
            rel.transitionSigned    = pt.Signed_Transition_Agreement__c    == true;
            rel.transitionCommitted = pt.Transition_Commitment_Complete__c == true;
            rel.fundedReceiverPath  = pt.Funded_Receiver_Path__c           == true;
            rel.integrationPlan     = pt.Integration_Plan__c               == true;
            rel.transitionOwner     = pt.Transition_Owner__c;
            rel.testVenue           = pt.Test_Venue__c;
            rel.hasTransition       = true;
        }

        for (AggregateResult ar : [
            SELECT Decision__c dec, COUNT(Id) cnt
            FROM pm_Evidence__c WHERE pm_Program__c = :recordId AND Decision__c != null
            GROUP BY Decision__c
        ]) {
            String dec = (String)ar.get('dec');
            Integer cnt = (Integer)ar.get('cnt');
            if (dec == 'Continue') rel.evidenceContinue = cnt;
            else if (dec == 'Pivot') rel.evidencePivot = cnt;
        }
        AggregateResult avgDays = [
            SELECT AVG(Days_to_Decision__c) avg
            FROM pm_Evidence__c WHERE pm_Program__c = :recordId AND Days_to_Decision__c != null
        ];
        if (avgDays.get('avg') != null) {
            rel.evidenceAvgDays = ((Decimal)avgDays.get('avg')).setScale(1);
        }

        List<AggregateResult> upeResults = [
            SELECT Engagement_Type__c etype, COUNT(Id) cnt, SUM(Participant_Count__c) pax
            FROM pm_User_Partner_Engagement__c WHERE pm_Program__c = :recordId
            GROUP BY Engagement_Type__c ORDER BY COUNT(Id) DESC
        ];
        Integer maxCnt = 0;
        for (AggregateResult ar : upeResults) {
            Integer c = (Integer)ar.get('cnt');
            if (c > maxCnt) maxCnt = c;
        }
        for (AggregateResult ar : upeResults) {
            Integer cnt = (Integer)ar.get('cnt');
            Integer pax = ar.get('pax') != null ? (Integer)((Decimal)ar.get('pax')) : 0;
            Integer pct = maxCnt > 0 ? (cnt * 100 / maxCnt) : 0;
            String  et  = (String)ar.get('etype');
            rel.engagements.add(new EngagementRow(et != null ? et : 'Other', cnt, pax, pct));
        }

        return rel;
    }

    public class ProgramDetail {
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public String  fundAllocation;
        @AuraEnabled public String  programBalance;
        @AuraEnabled public Date    awardDate;
        @AuraEnabled public Date    fundingStartDate;
        @AuraEnabled public Date    firstPrototypeDate;
        @AuraEnabled public Date    successfulDemoDate;
        @AuraEnabled public Date    missionNeedValidatedDate;
        @AuraEnabled public Date    missionUseDate;
        @AuraEnabled public Decimal timeAwardToPrototypeMonths;
        @AuraEnabled public Decimal timeDemoToMissionUseMonths;
        @AuraEnabled public Decimal timeMissionToFundedDays;
        @AuraEnabled public Decimal experimentCadence;
        @AuraEnabled public Integer engagementCount;
        @AuraEnabled public Decimal operationalIndex;
        @AuraEnabled public String  operationalOutcomes;
        @AuraEnabled public Boolean isTransitioned;
        @AuraEnabled public String  transitionOutcome;

        public ProgramDetail(pm_Program__c p) {
            this.name                     = p.Name;
            this.status                   = p.Program_Status__c;
            this.fundAllocation           = p.Fund_Allocation__c;
            this.programBalance           = p.Program_Balance__c;
            this.awardDate                = p.Award_Date__c;
            this.fundingStartDate         = p.Funding_Start_Date__c;
            this.firstPrototypeDate       = p.First_Prototype_Date__c;
            this.successfulDemoDate       = p.Successful_Demo_Date__c;
            this.missionNeedValidatedDate = p.Mission_Need_Validated_Date__c;
            this.missionUseDate           = p.Mission_Use_Date__c;
            this.timeAwardToPrototypeMonths = p.Time_Award_to_Prototype_Months__c;
            this.timeDemoToMissionUseMonths = p.Time_Demo_to_MissionUse_Months__c;
            this.timeMissionToFundedDays    = p.Time_Mission_to_Funded_Days__c;
            this.experimentCadence        = p.Experiment_Cadence__c;
            this.engagementCount          = p.Engagement_Count__c != null ? (Integer)p.Engagement_Count__c : 0;
            this.operationalIndex         = p.Operational_Index__c;
            this.operationalOutcomes      = p.Operational_Outcomes__c;
            this.isTransitioned           = p.Is_Transitioned__c == true;
            this.transitionOutcome        = p.Transition_Outcome__c;
        }
    }

    public class ProgramRelated {
        @AuraEnabled public Integer currentTrl;
        @AuraEnabled public Integer previousTrl;
        @AuraEnabled public Decimal trlGain;
        @AuraEnabled public Date    trlDate;
        @AuraEnabled public String  trlElement;
        @AuraEnabled public Integer currentMrl;
        @AuraEnabled public Integer previousMrl;
        @AuraEnabled public Decimal mrlGain;
        @AuraEnabled public Date    mrlDate;
        @AuraEnabled public Decimal examPassRate;
        @AuraEnabled public Integer examsAdministered;
        @AuraEnabled public Integer examsPass;
        @AuraEnabled public Date    examDate;
        @AuraEnabled public String  examType;
        @AuraEnabled public Boolean hasTransition       = false;
        @AuraEnabled public String  transitionType;
        @AuraEnabled public Boolean transitionSigned    = false;
        @AuraEnabled public Boolean transitionCommitted = false;
        @AuraEnabled public Boolean fundedReceiverPath  = false;
        @AuraEnabled public Boolean integrationPlan     = false;
        @AuraEnabled public String  transitionOwner;
        @AuraEnabled public String  testVenue;
        @AuraEnabled public Integer evidenceContinue    = 0;
        @AuraEnabled public Integer evidencePivot       = 0;
        @AuraEnabled public Decimal evidenceAvgDays;
        @AuraEnabled public List<EngagementRow> engagements = new List<EngagementRow>();
    }

    public class EngagementRow {
        @AuraEnabled public String  engagementType;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer participants;
        @AuraEnabled public Integer pct;
        public EngagementRow(String et, Integer cnt, Integer pax, Integer pct) {
            this.engagementType = et;
            this.count          = cnt;
            this.participants   = pax;
            this.pct            = pct;
        }
    }
}
