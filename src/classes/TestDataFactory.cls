public with sharing class TestDataFactory {
	public TestDataFactory() {}

	public List<Account> createAccounts(Integer count){
		List<Account> accts = new List<Account>(); 
		for(Integer i = 0; i < count; i++) {
			Account a = new Account(Name = 'Test Account ' + String.valueOf(count));
			accts.add(a);
		}
		return accts; 
	}

	public List<Contact> createContacts(Integer count, String accountId, String cohortId){
		List<Contact> conts = new List<Contact>(); 
		for(Integer i = 0; i < count; i++) {
			Contact c = new Contact(LastName = 'Test Contact ' + String.valueOf(count));
			if(accountId != null && accountId != '') c.AccountId = accountId;
			if(cohortId != null && cohortId != '') c.Cohort__c = cohortId; 
			conts.add(c);
		}
		return conts; 
	}

	public List<Cohort__c> createCohorts(Integer count){
		List<Cohort__c> cohorts = new List<Cohort__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort__c c = new Cohort__c(Name = 'Test Cohort ' + String.valueOf(count));
			cohorts.add(c);
		}
		return cohorts;
	}

	public List<Cohort_Learning_Plan__c> createLearningPlans(Integer count, String cohortId){
		list<Cohort_Learning_Plan__c> learningPlans = new List<Cohort_Learning_Plan__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort_Learning_Plan__c l = new Cohort_Learning_Plan__c(Name = 'Test Learning Plan ' + String.valueOf(count));
			if(cohortId != null && cohortId != ''){
				l.Cohort__c = cohortId;
				learningPlans.add(l);
			} 
		}
		return learningPlans;
	}

	public List<Cohort_Semester_Course__c> createSemesterCourses (Integer count, String learningPlanId, String courseId, String semester, String year){
		List<Cohort_Semester_Course__c> semesterCourses = new List<Cohort_Semester_Course__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort_Semester_Course__c sc = new Cohort_Semester_Course__c(Name = 'Test Semester Course ' + String.valueOf(count),
																		 Semester__c = semester, 
																		 Year__c = year);
			if(courseId != null) sc.Cohort_Course__c = courseId;
			if(learningPlanId != null){
				sc.Cohort_Learning_Plan__c = learningPlanId;
				semesterCourses.add(sc);
			}
		}
		return semesterCourses;
	}

	public List<Cohort_Course__c> createCourses(Integer count){
		List<Cohort_Course__c> courses = new List<Cohort_Course__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort_Course__c c = new Cohort_Course__c(Name = 'Test Course ' + String.valueOf(count));
			courses.add(c);
		}
		return courses;
	}

	public List<Cohort_Course_Section__c> createSections(Integer count, String courseId, String semester, String year) {
		List<Cohort_Course_Section__c> sections = new List<Cohort_Course_Section__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort_Course_Section__c s = new Cohort_Course_Section__c(Name = 'Test Course Section ' + String.valueOf(count),
																		 Semester__c = semester, 
																		 Year__c = year,
																		 Section__c = String.valueOf(count),
																		 Days__C = 'MWF',
																		 Start_Time__c = '08:00',
																		 End_Time__c = '10:00');		
			if(courseId != null && courseId != '') {
				s.Cohort_Course__c = courseId;
				sections.add(s);
			}	
		}
		return sections;
	}

	public List<Cohort_Semester_Template__c> createSemesterTemplates(Integer count, String lptId){
		list<Cohort_Semester_Template__c> semesterTemplates = new List<Cohort_Semester_Template__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort_Semester_Template__c s = new Cohort_Semester_Template__c(Name = 'Test Semester ' + String.valueOf(count));
			if(lptId != null && lptId != ''){
				s.Cohort_Learning_Plan_Template__c = lptId;
				semesterTemplates.add(s);
			} 
		}
		return semesterTemplates;
	}

	public List<Cohort_Course_Template__c> createCourseTemplates(Integer count, String semesterId, String courseId){
		list<Cohort_Course_Template__c> courseTemplates = new List<Cohort_Course_Template__c>(); 
		for(Integer i = 0; i < count; i++) {
			Cohort_Course_Template__c c = new Cohort_Course_Template__c(Name = 'Test Course ' + String.valueOf(count),
																			Cohort_Course__c = courseId);
			if(semesterId != null && semesterId != ''){
				c.Cohort_Semester_Template__c = semesterId;
				courseTemplates.add(c);
			} 
		}
		return courseTemplates;
	}


}