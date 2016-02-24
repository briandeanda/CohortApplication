@isTest(SeeAllData=true)
public class ScheduleTestClass {
	public static testMethod void testFreshmanApex() { 
        test.startTest();
        Schedule s = new Schedule();
        Student_Info__c si = schedule.addOrUpdateUser('test', 'se', 'test', 'testschool', 'none', 'fresh', 'first', 'last', 'none', 'cs', 'fall', 2016, 'un');
        Student_Info__c testSI = new Student_Info__c(Student_ID_n__c = 'test', Student_ID__c = 123, Name__c='test mctest');
        insert testSI;
        schedule.setDefaultForStudent('test', si.Id+'', Integer.valueOf(si.Start_Year__c), 'fys-se');
        schedule.addEnrollment('test', 'CST 300', 2012, 'fall');
        schedule.changeSubmissionState('test', 'SUB');
        schedule.removeAllEnrollmentForStudent('test');
        schedule.getUser(si.Student_ID__c+''); 
        schedule.getUserFromGoogleID(si.GoogleID__c);
        schedule.getUsersFromNameSUB(si.Name__c);
        //schedule.changeSubmissionState(si.Student_ID__c+'', 'APR');
        schedule.getUsersFromNameAPR(si.Name__c);
        //schedule.changeSubmissionState(si.Student_ID__c+'', 'UN');
        schedule.getUsersFromNameUN(si.Name__c);
        
        List<Student_Info__c> pathways = schedule.getPathways();
        
        schedule.userExists(si.Student_ID__c+'');
        
        schedule.getSubmittedILPs();
		schedule.getUnSubmittedILPs();
		schedule.getApprovedILPs();
        
        schedule.getOutcomes(si.Concentration__c);
        
        schedule.getAdmin(si.GoogleID__c);
        
		schedule.saveComments(si.GoogleID__c, 'TEST');
        schedule.saveChatBox(si.GoogleID__c, 'TEST');
        
        String comments = schedule.getComments(si.GoogleID__c);
        String chat = schedule.getChatBox(si.GoogleID__c);
        
		List<String> majorClasses = schedule.getMajorElectives(si.Concentration__c);
        
        test.stopTest();
    }
}