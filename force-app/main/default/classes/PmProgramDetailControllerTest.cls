@IsTest
private class PmProgramDetailControllerTest {

    @TestSetup
    static void setupData() {
        pm_Program__c program = new pm_Program__c(
            Name = 'Detail Program',
            Program_Status__c = 'Transitioning',
            Fund_Allocation__c = 'Threat-Informed',
            Program_Balance__c = 'Commercial Adoption',
            Mission_Need_Validated_Date__c = Date.newInstance(2024, 1, 15),
            Funding_Start_Date__c = Date.newInstance(2024, 3, 1),
            Award_Date__c = Date.newInstance(2024, 6, 1),
            First_Prototype_Date__c = Date.newInstance(2025, 1, 10),
            Successful_Demo_Date__c = Date.newInstance(2025, 6, 1),
            Mission_Use_Date__c = Date.newInstance(2025, 9, 1),
            Experiment_Cadence__c = 3,
            Operational_Index__c = 72,
            Operational_Outcomes__c = 'Improved Detection',
            Transition_Outcome__c = 'Operational Experiment'
        );
        insert program;

        insert new pm_TRL__c(
            pm_Program__c = program.Id,
            Technology_Element__c = 'Sensor Suite',
            Current_TRL__c = 7,
            Previous_TRL__c = 5,
            Assessment_Date__c = Date.today()
        );
        insert new pm_MRL__c(
            pm_Program__c = program.Id,
            Manufacturing_Capability__c = 'Pilot Line',
            Current_MRL__c = 6,
            Previous_MRL__c = 4,
            Assessment_Date__c = Date.today()
        );
        insert new pm_Technical_Exam__c(
            pm_Program__c = program.Id,
            Exam_Type__c = 'Final',
            Exam_Date__c = Date.today(),
            Exams_Administered__c = 8,
            Exams_Pass__c = 7
        );
        // Leave Integration_Plan__c false so Transition_Commitment_Complete__c formula stays false.
        insert new pm_Project_Transition__c(
            pm_Program__c = program.Id,
            Prototype_Transition__c = 'Fielded Prototype',
            Signed_Transition_Agreement__c = true,
            Funded_Receiver_Path__c = true,
            Integration_Plan__c = false,
            Transition_Owner__c = 'Transition Lead',
            Test_Venue__c = 'Lab B'
        );
        insert new pm_Evidence__c(
            pm_Program__c = program.Id,
            Evidence_Provided_Date__c = Date.today().addDays(-20),
            Decision_Date__c = Date.today().addDays(-10),
            Decision__c = 'Continue'
        );
        insert new pm_Evidence__c(
            pm_Program__c = program.Id,
            Evidence_Provided_Date__c = Date.today().addDays(-30),
            Decision_Date__c = Date.today().addDays(-18),
            Decision__c = 'Pivot'
        );
        insert new pm_User_Partner_Engagement__c(
            pm_Program__c = program.Id,
            Engagement_Type__c = 'Acquirer/Program Office',
            Engagement_Date__c = Date.today(),
            Participant_Count__c = 4
        );
    }

    private static Id programId() {
        return [SELECT Id FROM pm_Program__c WHERE Name = 'Detail Program' LIMIT 1].Id;
    }

    @IsTest
    static void getProgramDetail_returnsNullForBlankId() {
        Test.startTest();
        PmProgramDetailController.ProgramDetail detail = PmProgramDetailController.getProgramDetail(null);
        Test.stopTest();
        System.assertEquals(null, detail);
    }

    @IsTest
    static void getProgramDetail_mapsProgramFields() {
        Id recordId = programId();

        Test.startTest();
        PmProgramDetailController.ProgramDetail detail = PmProgramDetailController.getProgramDetail(recordId);
        Test.stopTest();

        System.assertEquals('Detail Program', detail.name);
        System.assertEquals('Transitioning', detail.status);
        System.assertEquals('Threat-Informed', detail.fundAllocation);
        System.assertEquals('Commercial Adoption', detail.programBalance);
        System.assertEquals(Date.newInstance(2024, 6, 1), detail.awardDate);
        System.assertEquals(3, detail.experimentCadence);
        System.assertEquals(72, detail.operationalIndex);
        System.assertEquals(true, detail.isTransitioned);
        System.assertEquals('Operational Experiment', detail.transitionOutcome);
        System.assertNotEquals(null, detail.timeMissionToFundedDays);
        System.assertNotEquals(null, detail.timeAwardToPrototypeMonths);
        System.assertNotEquals(null, detail.timeDemoToMissionUseMonths);
    }

    @IsTest
    static void getProgramRelated_returnsNullForBlankId() {
        Test.startTest();
        PmProgramDetailController.ProgramRelated related = PmProgramDetailController.getProgramRelated(null);
        Test.stopTest();
        System.assertEquals(null, related);
    }

    @IsTest
    static void getProgramRelated_mapsChildRecords() {
        Id recordId = programId();

        Test.startTest();
        PmProgramDetailController.ProgramRelated related = PmProgramDetailController.getProgramRelated(recordId);
        Test.stopTest();

        System.assertEquals(7, related.currentTrl);
        System.assertEquals(5, related.previousTrl);
        System.assertEquals(2, related.trlGain);
        System.assertEquals('Sensor Suite', related.trlElement);

        System.assertEquals(6, related.currentMrl);
        System.assertEquals(4, related.previousMrl);
        System.assertEquals(2, related.mrlGain);

        System.assertEquals(87.5, related.examPassRate);
        System.assertEquals(8, related.examsAdministered);
        System.assertEquals(7, related.examsPass);
        System.assertEquals('Final', related.examType);

        System.assertEquals(true, related.hasTransition);
        System.assertEquals('Fielded Prototype', related.transitionType);
        System.assertEquals(true, related.transitionSigned);
        System.assertEquals(false, related.transitionCommitted);
        System.assertEquals(true, related.fundedReceiverPath);
        System.assertEquals(false, related.integrationPlan);
        System.assertEquals('Transition Lead', related.transitionOwner);
        System.assertEquals('Lab B', related.testVenue);

        System.assertEquals(1, related.evidenceContinue);
        System.assertEquals(1, related.evidencePivot);
        System.assertNotEquals(null, related.evidenceAvgDays);

        System.assertEquals(1, related.engagements.size());
        System.assertEquals('Acquirer/Program Office', related.engagements[0].engagementType);
        System.assertEquals(1, related.engagements[0].count);
        System.assertEquals(4, related.engagements[0].participants);
        System.assertEquals(100, related.engagements[0].pct);
    }
}
