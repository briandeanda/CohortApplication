public with sharing class CohortScheduledCourseViewController {
	private static Map<String, List<Cohort_Scheduled_Course__c>> courseMapBySchedule;
	public CohortScheduledCourseViewController() {}

	public String getId() {
		return ApexPages.currentPage ().getParameters().get('ID');
	}

	@RemoteAction
	public static String getClassSchedules(String cohortId) {
		System.debug('cohortId: ' + cohortId);
		List<Cohort_Schedule__c> classSchedules = [
			SELECT Id, Name, Semester__c, Year__c, Selected_Schedule__c, 
				(SELECT Id, Name, Cohort_Course_Section__r.Start_Time__c, Cohort_Course_Section__r.End_Time__c,
					Cohort_Course_Section__r.Section__c, Cohort_Course_Section__r.Number__c, 
					Cohort_Course_Section__r.Days__c, Cohort_Course_Section__r.Subject__c, 
					Cohort_Course_Section__r.Capacity__c, Cohort_Course_Section__r.Units__c
				FROM Cohort_Scheduled_Courses__r
				ORDER BY Cohort_Course_Section__r.Start_Time__c)
			FROM Cohort_Schedule__c
			WHERE Cohort__c =: cohortId
			ORDER BY Name
		];

		return JSON.serialize(classSchedules);
	}

	@RemoteAction
	public static String toggleSelectSchedule(String scheduleId) {
		System.debug('scheduleId: ' + scheduleId);
		boolean success = false;
		List<Cohort_Schedule__c> cSchedule = [
			SELECT Id, Selected_Schedule__c, Cohort__c, 
				(SELECT Id, Cohort_Course_Section__c
				 FROM Cohort_Scheduled_Courses__r)
			FROM Cohort_Schedule__c
			WHERE Id =: scheduleId
		];

		System.debug('cSchedule: ' + cSchedule);
		if (cSchedule != null && !cSchedule.isEmpty()) {
			Cohort_Schedule__c theSchedule = cSchedule[0];

			theSchedule.Selected_Schedule__c = !theSchedule.Selected_Schedule__c;
			System.debug('cSchedule: ' + cSchedule);
			update cSchedule;
			success = true;

			if (theSchedule.Selected_Schedule__c == true) {
				System.debug('Creating block registrations');
				//we've selected a schedule. Create the Block Registration for it now
				List<Contact> students = [
					SELECT Id 
					FROM Contact 
					WHERE Cohort__c =: theSchedule.Cohort__c
				];

				List<Cohort_Block_Registration__c> blockRegistrations = new List<Cohort_Block_Registration__c>(); 
				for (Cohort_Scheduled_Course__c csc : theSchedule.Cohort_Scheduled_Courses__r) {
					for(Contact c : students) {
						blockRegistrations.add(new Cohort_Block_Registration__c(
							Student__c = c.Id,
							Cohort_Course_Section__c = csc.Cohort_Course_Section__c,
							Cohort_Schedule__c = scheduleId,
							Cohort__c = theSchedule.Cohort__c
						));
					}
				}

				if (!blockRegistrations.isEmpty()) {
					insert blockRegistrations;
				}
			}
			else {
				//the schedule was deselected, need to delete the block registrations
				System.debug('Deleting block registrations');
				List<Cohort_Block_Registration__c> blockRegistrations = [
					SELECT Id
					FROM Cohort_Block_Registration__c
					WHERE Cohort_Schedule__c =: theSchedule.Id
				];

				if (!blockRegistrations.isEmpty()) {
					delete blockRegistrations;
				}
			}
 		}

 		return '{"success" : ' + success + '}';
	}
}