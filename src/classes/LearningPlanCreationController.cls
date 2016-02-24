public with sharing class LearningPlanCreationController {

    public Cohort__c cohort {get; set;}
    public List<String> semesterKey {get; set;}
    public String startingSemester {get; set;} 
    public String startingYear {get; set;} 
    public String templateId {get; set;} 

    public LearningPlanCreationController(ApexPages.StandardController stdController) {
        
        String cohortId = stdController.getId();
        cohort = [SELECT Id, Starting_Year__c, Starting_Semester__c, Cohort_Learning_Plan_Template__c, Name FROM Cohort__c WHERE Id =: cohortId limit 1];
        startingSemester = cohort.Starting_Semester__c; 
        startingYear = cohort.Starting_Year__c; 
        templateId = cohort.Cohort_Learning_Plan_Template__c; 
        semesterKey = new List<String>{'Spring', 'Summer', 'Fall', 'Winter'}; 
        //(startingSemester == 'Fall' ? new List<String>{'Fall', 'Winter', 'Spring', 'Summer'} : new List<String>{'Spring', 'Summer', 'Fall', 'Winter'});


    }

    public PageReference createLearningPlan(){ 

        startingSemester = cohort.Starting_Semester__c; 
        startingYear = cohort.Starting_Year__c; 
        templateId = cohort.Cohort_Learning_Plan_Template__c;
        
        List<Cohort_Semester_Template__c> semTemplates = [SELECT Id, Semester_Number__c, (SELECT Id, Cohort_Course__c, Cohort_Course__r.Name FROM Cohort_Course_Templates__r),
                                                          Cohort_Learning_Plan_Template__r.Starting_Semester__c
                                                          FROM Cohort_Semester_Template__c 
                                                          WHERE Cohort_Learning_Plan_Template__c =: templateId
                                                          ORDER BY Semester_Number__c];
        
        if(semTemplates == null || semTemplates.isEmpty()){
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'No Semesters were found for the specified Learning Template'));
            return null;
        }

        if(semTemplates[0].Cohort_Learning_Plan_Template__r.Starting_Semester__c != startingSemester) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'The "Starting Semester" for the selected template does not match what is listed on the Cohort, please select another template'));
            return null;   
        }
        Cohort_Learning_Plan__c learningPlan = new Cohort_Learning_Plan__c(Name = 'Learning Plan for ' + cohort.Name,
                                                              Cohort__c = cohort.Id);
        insert learningPlan; 

        List<Cohort_Semester_Course__c> semCourses = new List<Cohort_Semester_Course__c>(); 
        Integer yearCount = 0;
        Integer semesterCount = (startingSemester == 'Fall' ? 2 : 0); 
        system.debug('@semesterKey ' + semesterKey);
        for(Cohort_Semester_Template__c st : semTemplates) {
            List<Cohort_Course_Template__c> ctemp = st.Cohort_Course_Templates__r;
            if(semesterCount == 4){
                yearCount ++;
                semesterCount = 0;
            }
            for(Cohort_Course_Template__c ct : ctemp) {
                Cohort_Semester_Course__c sc = new Cohort_Semester_Course__c();
                sc.Name = ct.Cohort_Course__r.Name; 
                sc.Cohort_Learning_Plan__c = learningPlan.Id; 
                sc.Year__c = String.valueOf(Integer.valueOf(startingYear) + yearCount);
                sc.Semester__c = semesterKey[semesterCount];
                sc.Cohort_Course__c = ct.Cohort_Course__c; 
                semCourses.add(sc);
            }
            semesterCount ++; 
        }

        system.debug('@semesterCourses: ' + semCourses);
        try{
            insert(semCourses);
            update cohort;     
        }
        catch (Exception e) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'Unable to create Learning Plan, please try again'));
            delete learningPlan; 
            return null;
        }

        ApexPages.addMessage(new ApexPages.message(ApexPages.severity.Info,'Learning Plan successfully created'));
        return null; 

    }

    
}