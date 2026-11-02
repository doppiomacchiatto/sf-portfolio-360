@IsTest
private class PmDashboardControllerTest {

    @TestSetup
    static void setupData() {
        pm_Program__c active = new pm_Program__c(
            Name = 'Alpha Program',
            Program_Status__c = 'Prototype',
            Fund_Allocation__c = 'Validated',
            Program_Balance__c = 'Near Term',
            Mission_Need_Validated_Date__c = Date.today().addDays(-200),
            Funding_Start_Date__c = Date.today().addDays(-100),
            Award_Date__c = Date.today().addDays(-90),
            First_Prototype_Date__c = Date.today().addDays(-30),
            Successful_Demo_Date__c = Date.today().addDays(-20),
            Mission_Use_Date__c = Date.today().addDays(-5),
            Experiment_Cadence__c = 4,
            Operational_Index__c = 80,
            Transition_Outcome__c = 'Program of Record'
        );
        pm_Program__c closed = new pm_Program__c(
            Name = 'Closed Program',
            Program_Status__c = 'Closed',
            Fund_Allocation__c = 'Security-Gap',
            Program_Balance__c = 'Mission Pull'
        );
        insert new List<pm_Program__c>{ active, closed };

        insert new pm_TRL__c(
            pm_Program__c = active.Id,
            Technology_Element__c = 'Propulsion',
            Current_TRL__c = 6,
            Previous_TRL__c = 4,
            Assessment_Date__c = Date.today()
        );
        insert new pm_MRL__c(
            pm_Program__c = active.Id,
            Manufacturing_Capability__c = 'Assembly',
            Current_MRL__c = 5,
            Previous_MRL__c = 3,
            Assessment_Date__c = Date.today()
        );
        insert new pm_Technical_Exam__c(
            pm_Program__c = active.Id,
            Exam_Type__c = 'Gate Review',
            Exam_Date__c = Date.today(),
            Exams_Administered__c = 10,
            Exams_Pass__c = 9
        );
        insert new pm_Evidence__c(
            pm_Program__c = active.Id,
            Evidence_Provided_Date__c = Date.today().addDays(-14),
            Decision_Date__c = Date.today().addDays(-7),
            Decision__c = 'Continue'
        );
        insert new pm_Evidence__c(
            pm_Program__c = active.Id,
            Evidence_Provided_Date__c = Date.today().addDays(-21),
            Decision_Date__c = Date.today().addDays(-10),
            Decision__c = 'Pivot'
        );
        insert new pm_User_Partner_Engagement__c(
            pm_Program__c = active.Id,
            Engagement_Type__c = 'User/Operator',
            Engagement_Date__c = Date.today(),
            Participant_Count__c = 5
        );
        insert new pm_User_Partner_Engagement__c(
            pm_Program__c = active.Id,
            Engagement_Type__c = 'Cyber/Mission Partner',
            Engagement_Date__c = Date.today(),
            Participant_Count__c = 2
        );
        // Transition_Commitment_Complete__c is a formula of owner + signed + funded path + plan + venue.
        insert new pm_Project_Transition__c(
            pm_Program__c = active.Id,
            Prototype_Transition__c = 'Program of Record',
            Signed_Transition_Agreement__c = true,
            Funded_Receiver_Path__c = true,
            Integration_Plan__c = true,
            Transition_Owner__c = 'Ops Lead',
            Test_Venue__c = 'Range A'
        );

        insert new Task(
            Subject = 'Review TRL package',
            Status = 'Not Started',
            Priority = 'High',
            ActivityDate = Date.today().addDays(7),
            WhatId = active.Id
        );
        insert new Case(
            Subject = 'Supply chain risk',
            Status = 'New',
            Priority = 'High',
            Origin = 'Web'
        );
    }

    @IsTest
    static void getKpiData_returnsAggregatesFromSeededPrograms() {
        Test.startTest();
        PmDashboardController.KpiData kpi = PmDashboardController.getKpiData();
        Test.stopTest();

        System.assertEquals(1, kpi.totalPrograms, 'Closed programs should be excluded');
        System.assertNotEquals(null, kpi.avgMissionToFundedDays);
        System.assertNotEquals(null, kpi.avgAwardToPrototypeMonths);
        System.assertNotEquals(null, kpi.avgDemoToMissionUseMonths);
        System.assertEquals(2, kpi.avgTrlGain);
        System.assertEquals(2, kpi.avgMrlGain);
        System.assertEquals(90, kpi.avgExamPassRate);
        System.assertEquals(2, kpi.totalDecisions);
        System.assertEquals(2, kpi.totalEngagements);
        System.assertEquals(1, kpi.transitionsCommitted);
        System.assertEquals(1, kpi.transitionsTotal);
        System.assertEquals(1, kpi.programsTransitioned);
        System.assertEquals(80, kpi.avgOperationalIndex);
    }

    @IsTest
    static void getPipelineData_returnsCanonicalPhasesWithCounts() {
        Test.startTest();
        List<PmDashboardController.PipelinePhase> phases = PmDashboardController.getPipelineData();
        Test.stopTest();

        System.assertEquals(5, phases.size(), 'Expected five canonical pipeline phases');
        Map<String, Integer> countsByLabel = new Map<String, Integer>();
        for (PmDashboardController.PipelinePhase phase : phases) {
            countsByLabel.put(phase.label, phase.count);
        }
        System.assertEquals(1, countsByLabel.get('Prototype'));
        System.assert(countsByLabel.containsKey('Ideation'));
        System.assert(countsByLabel.containsKey('Funded / Awarded'));
    }

    @IsTest
    static void getMyPrograms_returnsProgramRows() {
        Test.startTest();
        List<PmDashboardController.ProgramRow> rows = PmDashboardController.getMyPrograms();
        Test.stopTest();

        System.assert(rows.size() >= 2, 'Expected active and closed programs');
        System.assertNotEquals(null, rows[0].id);
        System.assertNotEquals(null, rows[0].name);
        System.assertNotEquals(null, rows[0].status);
    }

    @IsTest
    static void getMyTasks_returnsOpenTasksLinkedToPrograms() {
        Test.startTest();
        List<PmDashboardController.TaskRow> rows = PmDashboardController.getMyTasks();
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('Review TRL package', rows[0].subject);
        System.assertEquals('High', rows[0].priority);
    }

    @IsTest
    static void getOpenRisks_returnsOpenCases() {
        Test.startTest();
        List<PmDashboardController.RiskCaseRow> rows = PmDashboardController.getOpenRisks();
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('Supply chain risk', rows[0].subject);
        System.assertNotEquals(null, rows[0].caseNumber);
    }

    @IsTest
    static void getPortfolioMix_groupsFundAndBalance() {
        Test.startTest();
        PmDashboardController.PortfolioMix mix = PmDashboardController.getPortfolioMix();
        Test.stopTest();

        System.assertEquals(1, mix.total);
        System.assertEquals(1, mix.fundAllocation.size());
        System.assertEquals('Validated', mix.fundAllocation[0].label);
        System.assertEquals(100, mix.fundAllocation[0].pct);
        System.assertEquals(1, mix.portfolioBalance.size());
        System.assertEquals('Near Term', mix.portfolioBalance[0].label);
    }

    @IsTest
    static void getReadinessData_includesLatestTrlAndMrl() {
        Test.startTest();
        List<PmDashboardController.ReadinessRow> rows = PmDashboardController.getReadinessData();
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Closed programs excluded');
        System.assertEquals('Alpha Program', rows[0].name);
        System.assertEquals(6, rows[0].trl);
        System.assertEquals(5, rows[0].mrl);
    }

    @IsTest
    static void getEvidenceSummary_aggregatesContinueAndPivot() {
        Test.startTest();
        PmDashboardController.EvidenceSummary summary = PmDashboardController.getEvidenceSummary();
        Test.stopTest();

        System.assertEquals(1, summary.continueCount);
        System.assertEquals(1, summary.pivotCount);
        System.assertNotEquals(null, summary.avgDaysToDecision);
    }

    @IsTest
    static void getUpeBreakdown_returnsEngagementTypes() {
        Test.startTest();
        List<PmDashboardController.UpeRow> rows = PmDashboardController.getUpeBreakdown();
        Test.stopTest();

        System.assertEquals(2, rows.size());
        System.assertEquals(100, rows[0].pct);
        System.assertNotEquals(null, rows[0].engagementType);
    }

    @IsTest
    static void getTransitions_returnsTransitionRows() {
        Test.startTest();
        List<PmDashboardController.TransitionRow> rows = PmDashboardController.getTransitions();
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('Alpha Program', rows[0].programName);
        System.assertEquals('Program of Record', rows[0].transitionType);
        System.assertEquals(true, rows[0].signed);
        System.assertEquals(true, rows[0].committed);
    }
}
