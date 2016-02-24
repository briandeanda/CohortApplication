public with sharing class schedule {
	public String courseslistAvailable {get; set;}
    public String coursesPreqs {get; set;}
    public String coursesCoreqs {get; set;}
    public String coursesOutcomes {get; set;}
    public String pathwaysArray {get; set;}
    public String questionsArray {get; set;}
    public String concentrationsArray {get; set;}
    
    public Schedule(){
        List<Class__c> classes = [SELECT Name, Units__c, URL__c, Class_Type__c, Outcomes__c, Semester_Offered__c FROM Class__c ORDER BY Name];
        courseslistAvailable = JSON.serializePretty(classes);
        
        List<Preq__c> preqs = [SELECT Prev_Class__r.Name, Next_Class__r.Name FROM Preq__c];
        coursesPreqs = JSON.serializePretty(preqs);
        
        List<Coreq__c> coreqs = [SELECT Course__c, Name, Coreq_Course__c FROM Coreq__c];
        coursesCoreqs = JSON.serializePretty(coreqs);
        
        List<Outcome__c> outcomes = [SELECT Name FROM Outcome__c];
        coursesOutcomes = JSON.serializePretty(outcomes);
        
        List<Student_Info__c> pathways = [SELECT Id, Concentration__c, GoogleID__c, Incoming_Status__c, Starting_Semester__c, Name__c, Last_Name__c, Cohort__c, Major__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c, SubmissionState__c FROM Student_Info__c WHERE Name__c = 'pathway' ORDER BY Name ASC];
        pathwaysArray = JSON.serializePretty(pathways);
        
        List<Question__c> questions = [SELECT Name, Yes__c, No__c, QuestionText__c FROM Question__c ORDER BY Name ASC];
        questionsArray = JSON.serializePretty(questions);
        
        List<Concentration__c> con = [SELECT Name, RealName__c FROM Concentration__c];
        concentrationsArray = JSON.serializePretty(con);
    }
    
    @RemoteAction
    public static Boolean setDefaultForStudent(String studentID, String id, Integer year, String pathway) 
    {
        try { removeAllEnrollmentForStudent(studentID); } catch(Exception ex) { }
        List<Enrollment__c> classes = getILP(pathway);
        if(classes.size() == 0) { return true; }
        Decimal startYear = classes[0].Year_Enrolled__c;
        for(Enrollment__c e : classes) 
        {
            Enrollment__c ee = e.clone();
            Decimal diff = ee.Year_Enrolled__c - startYear;
            ee.Student__c = id;
            ee.Year_Enrolled__c = year + diff;
            insert ee;
        }
        return true;
    }
    
    @RemoteAction
    public static Student_Info__c addOrUpdateUser(String studentID, String concentration, String googleID,
                                          String highSchool, String priorCollege,
                                          String incomingStatus, String name, String lastName, String cohortSelection, String majorSelection, String semester, Integer year, String submissionState) 
    {
		Student_Info__c info = new Student_Info__c();
		if([SELECT Count() FROM Student_Info__c WHERE GoogleID__c = :googleID LIMIT 1] == 1) {
			info = [SELECT Id, Concentration__c, GoogleID__c, Incoming_Status__c, Starting_Semester__c, Name__c, Last_Name__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c, SubmissionState__c FROM Student_Info__c WHERE GoogleID__c = :googleId LIMIT 1];
   	        info.Concentration__c = concentration;
            info.GoogleID__c = googleID;
            info.Incoming_Status__c = incomingStatus;
            info.Starting_Semester__c = semester;
            info.Name__c = name;
			info.Last_Name__c = lastName;
            info.Cohort__c = cohortSelection;
            info.Major__c = majorSelection;
            info.Student_ID_n__c = studentID;
            info.Start_Year__c = year;
            info.Student_ID__c = 0;
            //info.Student_ID__c = integer.valueOf(studentID);
            info.Highschool__c = highSchool;
            info.PriorCollege__c = priorCollege;
            info.SubmissionState__c = submissionState;
            
            update info;
        } else {
            info.Concentration__c = concentration;
            info.GoogleID__c = googleID;
            info.Incoming_Status__c = incomingStatus;
            info.Starting_Semester__c = semester;
            info.Name__c = name;
			info.Last_Name__c = lastName;
            info.Cohort__c = cohortSelection;
            info.Major__c = majorSelection;
            info.Student_ID_n__c = studentID;
            info.Start_Year__c = year;
            info.Student_ID__c = 0;
            //info.Student_ID__c = integer.valueOf(studentID);
            info.Highschool__c = highSchool;
            info.PriorCollege__c = priorCollege;
            info.SubmissionState__c = submissionState;
            
            insert info;
        }
        
		return info;
	}
    
    @RemoteAction
    public static Boolean addEnrollment(String studentID, String className, Integer year, String semester) {
        Enrollment__c enrollment = new Enrollment__c();
        try {
        	enrollment.Student__c = [SELECT Id FROM Student_Info__c WHERE Student_Id_n__c = :studentID LIMIT 1].Id;
            enrollment.Class__c   = [SELECT Id FROM Class__c WHERE Name = :className LIMIT 1].Id;
            enrollment.Semester_Enrolled__c = semester;
            enrollment.Year_Enrolled__c 	= year;
        	insert enrollment;
        } catch (Exception ex) {
            return true;
        }
        return true;
    }
    
    @RemoteAction
    public static Boolean changeSubmissionState(String studentID, String submissionState) {
        Student_Info__c info = [SELECT Id, Concentration__c, GoogleID__c, Incoming_Status__c, Starting_Semester__c, Name__c, Last_Name__c, Cohort__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c, SubmissionState__c FROM Student_Info__c WHERE Student_ID_n__c = :studentID LIMIT 1];
   	    info.SubmissionState__c = submissionState;
        update info;
        return true;
    }
    
    @RemoteAction
    public static Boolean removeAllEnrollmentForStudent(String studentId) {
        if(studentId.length() == 0) {
            return true;
        }
        try {
            //Delete all enrollments with student id = studentId
            // The colon before studentId tell the query statement
            // that studentId is a variable and not just a String
            delete [SELECT Id FROM Enrollment__C WHERE Student__r.Student_Id_n__c = :studentId];
        } catch (Exception ex) {
            
        }
        return true;
    }
    
    @RemoteAction
    public static List<Enrollment__c> getILP(String studentId) {
        return [SELECT Class__r.Name, Semester_Enrolled__c, Year_Enrolled__c FROM Enrollment__c WHERE Student__r.Student_ID_n__c = :studentId];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getUser(String studentId) {
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, GoogleID__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c, SubmissionState__c FROM Student_Info__C WHERE Student_ID_n__c = :studentId LIMIT 1];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getUserFromGoogleID(String googleId) {
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, GoogleID__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c, SubmissionState__c FROM Student_Info__C WHERE GoogleID__c = :googleId LIMIT 1];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getUsersFromNameSUB(String name) {
        name = '%' + name + '%';
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, GoogleID__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c FROM Student_Info__c WHERE Name__c LIKE :name AND SubmissionState__c = 'SUB'];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getUsersFromNameAPR(String name) {
        name = '%' + name + '%';
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, GoogleID__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c FROM Student_Info__c WHERE Name__c LIKE :name AND SubmissionState__c = 'APR'];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getUsersFromNameUN(String name) {
        name = '%' + name + '%';
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, GoogleID__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c FROM Student_Info__c WHERE Name__c LIKE :name AND SubmissionState__c = 'UN'];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getPathways() {
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, Starting_Semester__c, Student_ID_n__c FROM Student_Info__c WHERE Name__c = 'pathway'];
    }
    
    @RemoteAction
    public static Boolean userExists(String studentId) {
        return [SELECT count() FROM Student_Info__c WHERE Student_Id_n__c = :studentId LIMIT 1] == 1;
    }
    
    @RemoteAction
    public static List<Student_Info__c> getSubmittedILPs() {
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c FROM Student_Info__c WHERE SubmissionState__c = 'SUB'];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getUnSubmittedILPs() {
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c FROM Student_Info__c WHERE SubmissionState__c = 'UN'];
    }
    
    @RemoteAction
    public static List<Student_Info__c> getApprovedILPs() {
        return [SELECT Concentration__c, Incoming_Status__c, Name__c, Last_Name__c, Cohort__c, Major__c, Start_Year__c, Starting_Semester__c, Student_ID_n__c, Student_ID__c, Highschool__c, PriorCollege__c FROM Student_Info__c WHERE SubmissionState__c = 'APR'];
    }
    
    @RemoteAction
    public static List<Outcome__c> getOutcomes(String concentration) {
        return [SELECT Name, Concentration__c FROM Outcome__c WHERE Concentration__c = '' OR Concentration__c = :concentration ORDER BY Name ASC];
    }
    
    @RemoteAction
    public static Admin__c getAdmin(String googleID) {
        try{
            return [SELECT GoogleID__c, Name__c FROM Admin__c WHERE GoogleID__c = :googleID LIMIT 1];
        } catch (Exception ex) {
            return null;
        }
    }
    
    @RemoteAction
    public static String getComments(String googleID) {
        return [SELECT Comments__c FROM Student_Info__c WHERE GoogleID__c =:googleID].Comments__c;
    }
    
    @RemoteAction
    public static String getChatBox(String googleID) {
        return [SELECT chatBox__c FROM Student_Info__c WHERE GoogleID__c = :googleID].chatBox__c;
    }
    
    @RemoteAction
    public static Boolean saveComments(String googleID, String comments) {
        Student_Info__c info = [SELECT Id, Comments__c FROM Student_Info__c WHERE GoogleID__c = :googleID LIMIT 1];
        info.Comments__c = comments;
        
        update info;
        return true;
    }
    
    @RemoteAction
    public static Boolean saveChatBox(String googleID, String chat) {
        Student_Info__c info = [SELECT Id, chatBox__c FROM Student_Info__c WHERE GoogleID__c = :googleID LIMIT 1];
        info.chatBox__c = chat;
        
        update info;
        return true;
    }
    
    @RemoteAction
    public static List<String> getMajorElectives(String concentration) {
        List<Class__c> cs = [SELECT Name, Outcomes__c FROM Class__c c WHERE c.Outcomes__c INCLUDES ('CSIT Elective')];
        List<String> realCs = new List<String>();
        for (Class__c c : cs) {
            String p = c.Outcomes__c;
            if([SELECT count() FROM Outcome__c WHERE Name LIKE :p AND Concentration__c != :concentration] > 0) {
            	realCs.add(c.Name);
            }
        }
        return realCs;
    }
    
    @RemoteAction
    public static Void sendEmail(String toEmail, String studentName, Integer messageType) {
        Messaging.reserveSingleEmailCapacity(2);
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        String[] toAddress = new String[] { toEmail };
        
        mail.setToAddresses(toAddress);
        
        mail.setReplyTo('do_not_reply@csumb.edu');
        mail.setSenderDisplayName('CSUMB_ILP_do_not_reply@csumb.edu');
        mail.setSubject('CSUMB ILP Update');
        mail.setBccSender(false);
        mail.setUseSignature(false);
        mail.setPlainTextBody('Thank you for using CSUMB ILP! Your changes have been saved.');
        
        if (messageType == 1) {
            mail.setHtmlBody(studentName + ',<br/><br/>Thank you for using CSUMB ILP! Your changes to your ILP have been saved.<br/><br/>Thank you,<br/>CSUMB ILP (do not reply)');
        }
        
        else if (messageType == 2) {
            mail.setHtmlBody(studentName + ',<br/><br/>Thank you for submitting your ILP! Your ILP has been successfully submitted for approval by your academic advisor.<br/><br/>Thank you,<br/>CSUMB ILP (do not reply)');
        }
        
        else if (messageType == 3) {
            mail.setHtmlBody(studentName + ',<br/><br/>Thank you for updating your account on CSUMB ILP! Any information related to your profile has been saved. <br/><br/>Thank you,<br/>CSUMB ILP (do not reply)');
        }
        
        else {
            mail.setHtmlBody('error');
        }
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        return;
    }
}