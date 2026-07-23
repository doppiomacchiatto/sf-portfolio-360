List<Program__c> rows = [
    SELECT Id, Name, OwnerId
    FROM Program__c
    WHERE Name LIKE '%Saturn%'
       OR Name LIKE '%Titan%'
       OR Name LIKE '%Enceladus%'
       OR Name LIKE '%Rhea%'
       OR Name LIKE '%Dione%'
       OR Name LIKE '%Iapetus%'
       OR Name LIKE '%Mimas%'
       OR Name LIKE '%Tethys%'
       OR Name LIKE '%Hyperion%'
       OR Name LIKE '%Phoebe%'
];

Id qId = [
    SELECT Id
    FROM Group
    WHERE Type = 'Queue'
      AND DeveloperName = 'Saturn_Programs'
    LIMIT 1
].Id;

for (Program__c p : rows) {
    p.OwnerId = qId;
}

if (!rows.isEmpty()) {
    update rows;
}

System.debug('Updated programs: ' + rows.size());
