public with sharing class PmDashboardController {

    @AuraEnabled(cacheable=true)
    public static KpiData getKpiData() {
        KpiData kpi = new KpiData();

        // KPI #1 & #2 — portfolio mix counts
        for (AggregateResult ar : [
            SELECT Fund_Allocation__c fund, Program_Balance__c balance, COUNT(Id) cnt
            FROM pm_Program__c
            WHERE Program_Status__c NOT IN ('Closed')
            GROUP BY Fund_Allocation__c, Program_Balance__c
        ]) {
            kpi.totalPrograms += (Integer)ar.get('cnt');
        }
        kpi.totalPrograms = [SELECT COUNT() FROM pm_Program__c WHERE Program_Status__c != 'Closed'];

        // KPI #3-5 — speed averages (months/days)
        AggregateResult speed = [
            SELECT AVG(Time_Award_to_Prototype_Months__c) avgProto,
                   AVG(Time_Demo_to_MissionUse_Months__c) avgDemo,
                   AVG(Time_Mission_to_Funded_Days__c) avgFunded
            FROM pm_Program__c
        ];
        kpi.avgAwardToPrototypeMonths = speed.get('avgProto') != null ? ((Decimal)speed.get('avgProto')).setScale(1) : null;
        kpi.avgDemoToMissionUseMonths = speed.get('avgDemo') != null ? ((Decimal)speed.get('avgDemo')).setScale(1) : null;
        kpi.avgMissionToFundedDays    = speed.get('avgFunded') != null ? ((Decimal)speed.get('avgFunded')).setScale(0) : null;

        // KPI #6 — avg TRL gain
        AggregateResult trl = [SELECT AVG(TRL_Gain__c) avgGain FROM pm_TRL__c];
        kpi.avgTrlGain = trl.get('avgGain') != null ? ((Decimal)trl.get('avgGain')).setScale(1) : null;

        // KPI #7 — avg MRL gain
        AggregateResult mrl = [SELECT AVG(MRL_Gain__c) avgGain FROM pm_MRL__c];
        kpi.avgMrlGain = mrl.get('avgGain') != null ? ((Decimal)mrl.get('avgGain')).setScale(1) : null;

        // KPI #8 — avg exam pass rate
        AggregateResult exam = [SELECT AVG(Pass_Rate__c) avgPass FROM pm_Technical_Exam__c];
        kpi.avgExamPassRate = exam.get('avgPass') != null ? ((Decimal)exam.get('avgPass')).setScale(0) : null;

        // KPI #9 — evidence decisions
        kpi.totalDecisions = [SELECT COUNT() FROM pm_Evidence__c WHERE Decision__c != null];

        // KPI #10 — total engagements
        AggregateResult eng = [SELECT SUM(Engagement_Count__c) total FROM pm_Program__c];
        kpi.totalEngagements = eng.get('total') != null ? (Integer)((Decimal)eng.get('total')) : 0;

        // KPI #11-13 — transition pipeline
        kpi.transitionsCommitted  = [SELECT COUNT() FROM pm_Project_Transition__c WHERE Transition_Commitment_Complete__c = true];
        kpi.transitionsTotal      = [SELECT COUNT() FROM pm_Project_Transition__c];
        kpi.programsTransitioned  = [SELECT COUNT() FROM pm_Program__c WHERE Is_Transitioned__c = true];

        // KPI #14 — avg operational index
        AggregateResult ops = [SELECT AVG(Operational_Index__c) avgOps FROM pm_Program__c WHERE Operational_Index__c != null];
        kpi.avgOperationalIndex = ops.get('avgOps') != null ? ((Decimal)ops.get('avgOps')).setScale(1) : null;

        return kpi;
    }

    @AuraEnabled(cacheable=true)
    public static List<PipelinePhase> getPipelineData() {
        Map<String, PipelinePhase> phaseMap = new Map<String, PipelinePhase>{
            'Ideation'         => new PipelinePhase('Ideation', 1, 'utility:einstein'),
            'Validated Need'   => new PipelinePhase('Validated Need', 2, 'utility:check'),
            'Funded'           => new PipelinePhase('Funded', 3, 'utility:money'),
            'Awarded'          => new PipelinePhase('Awarded', 3, 'utility:money'),
            'Prototype'        => new PipelinePhase('Prototype', 4, 'utility:component_customization'),
            'Demo Complete'    => new PipelinePhase('Demo Complete', 5, 'utility:play'),
            'Transitioning'    => new PipelinePhase('Transitioning', 5, 'utility:play'),
            'Operational'      => new PipelinePhase('Transitioning', 5, 'utility:play'),
            'Closed'           => new PipelinePhase('Closed', 0, 'utility:close')
        };

        for (AggregateResult ar : [
            SELECT Program_Status__c status, COUNT(Id) cnt
            FROM pm_Program__c
            GROUP BY Program_Status__c
        ]) {
            String status = (String)ar.get('status');
            Integer cnt   = (Integer)ar.get('cnt');
            if (phaseMap.containsKey(status)) {
                phaseMap.get(status).count += cnt;
            }
        }

        // Return 5 canonical pipeline phases (collapse Funded+Awarded, Demo+Transitioning+Operational)
        Map<Integer, PipelinePhase> canonical = new Map<Integer, PipelinePhase>();
        canonical.put(1, new PipelinePhase('Ideation',    1, 'utility:einstein'));
        canonical.put(2, new PipelinePhase('Validated Need', 2, 'utility:check'));
        canonical.put(3, new PipelinePhase('Funded / Awarded', 3, 'utility:money'));
        canonical.put(4, new PipelinePhase('Prototype',   4, 'utility:component_customization'));
        canonical.put(5, new PipelinePhase('Demo & Beyond', 5, 'utility:play'));

        for (PipelinePhase phase : phaseMap.values()) {
            if (phase.order > 0 && canonical.containsKey(phase.order)) {
                canonical.get(phase.order).count += phase.count;
            }
        }

        List<PipelinePhase> result = new List<PipelinePhase>(canonical.values());
        result.sort();
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgramRow> getMyPrograms() {
        List<ProgramRow> rows = new List<ProgramRow>();
        for (pm_Program__c p : [
            SELECT Id, Name, Program_Status__c, LastModifiedDate
            FROM pm_Program__c
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ]) {
            rows.add(new ProgramRow(
                p.Id,
                p.Name,
                p.Program_Status__c,
                p.LastModifiedDate
            ));
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<TaskRow> getMyTasks() {
        List<TaskRow> rows = new List<TaskRow>();
        for (Task t : [
            SELECT Id, Subject, Status, Priority, ActivityDate
            FROM Task
            WHERE IsClosed = false
            AND WhatId IN (SELECT Id FROM pm_Program__c)
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 10
        ]) {
            rows.add(new TaskRow(
                t.Id,
                t.Subject,
                t.Status,
                t.Priority,
                t.ActivityDate
            ));
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<RiskCaseRow> getOpenRisks() {
        List<RiskCaseRow> rows = new List<RiskCaseRow>();
        for (Case c : [
            SELECT Id, CaseNumber, Subject, Priority, Status, LastModifiedDate
            FROM Case
            WHERE IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ]) {
            rows.add(new RiskCaseRow(
                c.Id,
                c.CaseNumber,
                c.Subject,
                c.Priority,
                c.Status
            ));
        }
        return rows;
    }

    public class KpiData {
        @AuraEnabled public Integer totalPrograms            = 0;
        @AuraEnabled public Decimal avgAwardToPrototypeMonths;
        @AuraEnabled public Decimal avgDemoToMissionUseMonths;
        @AuraEnabled public Decimal avgMissionToFundedDays;
        @AuraEnabled public Decimal avgTrlGain;
        @AuraEnabled public Decimal avgMrlGain;
        @AuraEnabled public Decimal avgExamPassRate;
        @AuraEnabled public Integer totalDecisions           = 0;
        @AuraEnabled public Integer totalEngagements         = 0;
        @AuraEnabled public Integer transitionsCommitted     = 0;
        @AuraEnabled public Integer transitionsTotal         = 0;
        @AuraEnabled public Integer programsTransitioned     = 0;
        @AuraEnabled public Decimal avgOperationalIndex;
    }

    public class ProgramRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime lastUpdated;

        public ProgramRow(Id id, String name, String status, Datetime lastUpdated) {
            this.id = id;
            this.name = name;
            this.status = status;
            this.lastUpdated = lastUpdated;
        }
    }

    public class TaskRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Date dueDate;

        public TaskRow(Id id, String subject, String status, String priority, Date dueDate) {
            this.id = id;
            this.subject = subject;
            this.status = status;
            this.priority = priority;
            this.dueDate = dueDate;
        }
    }

    public class RiskCaseRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String priority;
        @AuraEnabled public String status;

        public RiskCaseRow(Id id, String caseNumber, String subject, String priority, String status) {
            this.id = id;
            this.caseNumber = caseNumber;
            this.subject = subject;
            this.priority = priority;
            this.status = status;
        }
    }

    public class PipelinePhase implements Comparable {
        @AuraEnabled public String  label;
        @AuraEnabled public Integer order;
        @AuraEnabled public String  icon;
        @AuraEnabled public Integer count = 0;

        public PipelinePhase(String label, Integer order, String icon) {
            this.label = label;
            this.order = order;
            this.icon  = icon;
        }

        public Integer compareTo(Object other) {
            return this.order - ((PipelinePhase)other).order;
        }
    }

    @AuraEnabled(cacheable=true)
    public static PortfolioMix getPortfolioMix() {
        Integer total = [SELECT COUNT() FROM pm_Program__c WHERE Program_Status__c != 'Closed'];
        PortfolioMix mix = new PortfolioMix();
        mix.total = total;
        for (AggregateResult ar : [
            SELECT Fund_Allocation__c val, COUNT(Id) cnt
            FROM pm_Program__c WHERE Program_Status__c != 'Closed'
            GROUP BY Fund_Allocation__c ORDER BY COUNT(Id) DESC
        ]) {
            mix.fundAllocation.add(new MixItem(
                (String)ar.get('val'), (Integer)ar.get('cnt'), total));
        }
        for (AggregateResult ar : [
            SELECT Program_Balance__c val, COUNT(Id) cnt
            FROM pm_Program__c WHERE Program_Status__c != 'Closed'
            GROUP BY Program_Balance__c ORDER BY COUNT(Id) DESC
        ]) {
            mix.portfolioBalance.add(new MixItem(
                (String)ar.get('val'), (Integer)ar.get('cnt'), total));
        }
        return mix;
    }

    @AuraEnabled(cacheable=true)
    public static List<ReadinessRow> getReadinessData() {
        Map<Id, ReadinessRow> rowMap = new Map<Id, ReadinessRow>();
        for (pm_Program__c p : [
            SELECT Id, Name, Program_Status__c FROM pm_Program__c
            WHERE Program_Status__c != 'Closed' ORDER BY Name
        ]) {
            rowMap.put(p.Id, new ReadinessRow(p.Id, p.Name, p.Program_Status__c));
        }
        Set<Id> ids = rowMap.keySet();
        Set<Id> trlDone = new Set<Id>();
        for (pm_TRL__c t : [
            SELECT pm_Program__c, Current_TRL__c FROM pm_TRL__c
            WHERE pm_Program__c IN :ids ORDER BY Assessment_Date__c DESC NULLS LAST
        ]) {
            if (!trlDone.contains(t.pm_Program__c)) {
                rowMap.get(t.pm_Program__c).trl = t.Current_TRL__c != null ? (Integer)t.Current_TRL__c : null;
                trlDone.add(t.pm_Program__c);
            }
        }
        Set<Id> mrlDone = new Set<Id>();
        for (pm_MRL__c m : [
            SELECT pm_Program__c, Current_MRL__c FROM pm_MRL__c
            WHERE pm_Program__c IN :ids ORDER BY Assessment_Date__c DESC NULLS LAST
        ]) {
            if (!mrlDone.contains(m.pm_Program__c)) {
                rowMap.get(m.pm_Program__c).mrl = m.Current_MRL__c != null ? (Integer)m.Current_MRL__c : null;
                mrlDone.add(m.pm_Program__c);
            }
        }
        return new List<ReadinessRow>(rowMap.values());
    }

    @AuraEnabled(cacheable=true)
    public static EvidenceSummary getEvidenceSummary() {
        EvidenceSummary es = new EvidenceSummary();
        for (AggregateResult ar : [
            SELECT Decision__c dec, COUNT(Id) cnt
            FROM pm_Evidence__c WHERE Decision__c != null
            GROUP BY Decision__c
        ]) {
            Integer cnt = (Integer)ar.get('cnt');
            String dec = (String)ar.get('dec');
            if (dec == 'Continue') es.continueCount = cnt;
            else if (dec == 'Pivot')   es.pivotCount   = cnt;
        }
        AggregateResult avg = [
            SELECT AVG(Days_to_Decision__c) avgDays FROM pm_Evidence__c
            WHERE Decision__c != null AND Days_to_Decision__c != null
        ];
        es.avgDaysToDecision = avg.get('avgDays') != null
            ? ((Decimal)avg.get('avgDays')).setScale(1) : null;
        return es;
    }

    @AuraEnabled(cacheable=true)
    public static List<UpeRow> getUpeBreakdown() {
        List<AggregateResult> results = [
            SELECT Engagement_Type__c etype, COUNT(Id) cnt, SUM(Participant_Count__c) pax
            FROM pm_User_Partner_Engagement__c
            GROUP BY Engagement_Type__c ORDER BY COUNT(Id) DESC
        ];
        Integer maxCnt = 0;
        for (AggregateResult ar : results) {
            Integer c = (Integer)ar.get('cnt');
            if (c > maxCnt) maxCnt = c;
        }
        List<UpeRow> rows = new List<UpeRow>();
        for (AggregateResult ar : results) {
            Integer cnt = (Integer)ar.get('cnt');
            Integer pax = ar.get('pax') != null ? (Integer)((Decimal)ar.get('pax')) : 0;
            Integer pct = maxCnt > 0 ? (cnt * 100 / maxCnt) : 0;
            String etype = (String)ar.get('etype');
            rows.add(new UpeRow(etype != null ? etype : 'Other', cnt, pax, pct));
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<TransitionRow> getTransitions() {
        List<TransitionRow> rows = new List<TransitionRow>();
        for (pm_Project_Transition__c t : [
            SELECT pm_Program__r.Name, Prototype_Transition__c,
                   Signed_Transition_Agreement__c, Transition_Commitment_Complete__c
            FROM pm_Project_Transition__c ORDER BY pm_Program__r.Name
        ]) {
            rows.add(new TransitionRow(
                t.pm_Program__r.Name, t.Prototype_Transition__c,
                t.Signed_Transition_Agreement__c == true,
                t.Transition_Commitment_Complete__c == true
            ));
        }
        return rows;
    }

    public class PortfolioMix {
        @AuraEnabled public Integer       total            = 0;
        @AuraEnabled public List<MixItem> fundAllocation   = new List<MixItem>();
        @AuraEnabled public List<MixItem> portfolioBalance = new List<MixItem>();
    }

    public class MixItem {
        @AuraEnabled public String  label;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer pct;
        public MixItem(String label, Integer count, Integer total) {
            this.label = label != null ? label : 'Unknown';
            this.count = count;
            this.pct   = total > 0 ? (count * 100 / total) : 0;
        }
    }

    public class ReadinessRow {
        @AuraEnabled public Id      programId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public Integer trl;
        @AuraEnabled public Integer mrl;
        public ReadinessRow(Id programId, String name, String status) {
            this.programId = programId;
            this.name      = name;
            this.status    = status;
        }
    }

    public class EvidenceSummary {
        @AuraEnabled public Integer continueCount     = 0;
        @AuraEnabled public Integer pivotCount        = 0;
        @AuraEnabled public Decimal avgDaysToDecision;
    }

    public class UpeRow {
        @AuraEnabled public String  engagementType;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer participants;
        @AuraEnabled public Integer pct;
        public UpeRow(String et, Integer cnt, Integer pax, Integer pct) {
            this.engagementType = et;
            this.count          = cnt;
            this.participants   = pax;
            this.pct            = pct;
        }
    }

    public class TransitionRow {
        @AuraEnabled public String  programName;
        @AuraEnabled public String  transitionType;
        @AuraEnabled public Boolean signed;
        @AuraEnabled public Boolean committed;
        public TransitionRow(String pn, String tt, Boolean s, Boolean c) {
            this.programName    = pn;
            this.transitionType = tt;
            this.signed         = s;
            this.committed      = c;
        }
    }
}
