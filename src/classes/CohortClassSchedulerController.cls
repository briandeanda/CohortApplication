public with sharing class CohortClassSchedulerController {
	
	public  final List<String> daysKey = new List<String> {'M', 'T', 'W', 'R', 'F'}; 
	public  integer scheduleCount = 1;
	public  Cohort__c cohort;
	public  Map<Integer, List<SObject>> goodSections = new Map<Integer, List<SObject>>(); 
	public  List<SelectOption> semesterList {get; set;}
	public  String selectedSemester {get; set;}
	public  String selectedYear {get; set;} 
	public	List<Contact> students {get; set;}
	public	Map<String, Cohort_Course_Section__c> labByCourseSection {get; set;}
	
	public CohortClassSchedulerController() {}

	public CohortClassSchedulerController (ApexPages.StandardController stdController) {

		cohort = (Cohort__c)stdController.getRecord();
        selectedYear = '';
        selectedSemester = '';
        semesterList = new List<SelectOption>(); 
        semesterList.add(new SelectOption('Spring','Spring'));
        semesterList.add(new SelectOption('Summer','Summer'));
        semesterList.add(new SelectOption('Fall','Fall'));
        semesterList.add(new SelectOption('Winter','Winter'));
        students = [SELECT Id FROM Contact WHERE Cohort__c =: cohort.Id];

       	system.debug('@students ' + students);

    }

	public PageReference getCourseSections () {
		if(selectedSemester == '' || selectedYear == '') {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'Please enter a Semsester and a Year'));
			return null; 
		}
		

		//Grab learning plan related to the cohort based on the year/semester specified by the user
		List<Cohort_Learning_Plan__c> learningPlans = [SELECT Id, 
													  (SELECT Cohort_Course__c FROM Cohort_Semester_Courses__r 
													   WHERE Semester__c =: selectedSemester AND Year__c =: selectedYear)
													   FROM Cohort_Learning_Plan__c
													   WHERE Cohort__c =: cohort.Id
													   LIMIT 1];
		
		if (learningPlans == null || learningPlans.isEmpty()) {
			//System.debug('No Learning Plans were found for the specified Cohort');
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'No Learning Plans were found for the specified Cohort'));
			return null;
		}		 

		List<Cohort_Semester_Course__c> semsesterCourses = learningPlans[0].Cohort_Semester_Courses__r;
		if (semsesterCourses == null || semsesterCourses.isEmpty()) {
			//System.debug('No Semester Courses were found for the specified semester and year');
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'No Semester Courses were found for the specified Semester and Year'));
			return null;
		}		 
       
		Set<String> courseIds = new Set<String>();
		for(Cohort_Semester_Course__c sc : semsesterCourses){
			courseIds.add(sc.Cohort_Course__c);
		}

		//grab all of the course sections related to the Cohort Courses on the returned Semester Courses
		List<Cohort_Course_Section__c> courseSections = [SELECT Id, Capacity__c, Start_Time__c, End_Time__c, Days__c, Cohort_Course__r.Name, Cohort_Course__c, 
															Section__c, Lab_Section__c, Association__c, Subject__c, Number__c
														 FROM Cohort_Course_Section__c
														 WHERE Cohort_Course__c IN: courseIds
														 AND Semester__c =: selectedSemester 
														 AND Year__c =: selectedYear];

		if (courseSections == null || courseSections.isEmpty()) {
			//System.debug('No Course Sections were found for the specified semester and year');
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'No Course Sections were found for the specified Semester and Year'));
			return null;
		}		 
		

		Map<String,Set<Cohort_Course_Section__c>> cmap = new Map<String,Set<Cohort_Course_Section__c>>();
		Map<String, List<Cohort_Course_Section__c>> labMap = new Map<String, List<Cohort_Course_Section__c>>(); 

		//map all of the course sections by course
		for ( Cohort_Course_Section__c c : courseSections ) {
				//separate out the lab sections as they need to be associated by course 
				if(!c.Lab_Section__c) {
			        Set<Cohort_Course_Section__c> cs = cmap.get(c.Cohort_Course__c);
			        if( cs == null ) {
			        	cs = new Set<Cohort_Course_Section__c>();
			        }
			        cs.add(c);
			        cmap.put(c.Cohort_Course__c, cs);
			    }
			    else {
			    	String key = c.Subject__c + c.Number__c; 
			    	List<Cohort_Course_Section__c> labs = labMap.get(key);
			    	if( labs == null ) {
			        	labs = new List<Cohort_Course_Section__c>();
			        }
			        labs.add(c);
			        labMap.put(key, labs);
			    }
		}

		labByCourseSection = new Map<String, Cohort_Course_Section__c>();
		//look for associated labs, if the association matches, removes it from the labmap
		for(Set<Cohort_Course_Section__c> cs : cmap.values() ) {
			for (Cohort_Course_Section__c c : cs ) {
				String key = c.Subject__c + c.Number__c; 
				List<Cohort_Course_Section__c> labs = labMap.get(key);
				if(labs != null) {
					Integer i = 0; 
					for(Cohort_Course_Section__c l : labs) {
						if(l.Association__c == c.Association__c) {
							labByCourseSection.put(c.Id, l);
							labs.remove(i);
							labMap.put(key, labs);
							break; 
						}
						i++; 
					}
				}
			}
		}

		Set<Cohort_Course_Section__c> freeLabs = new Set<Cohort_Course_Section__c>();
		//add all of the non associated labs to a set to include into cmap
		for(List<Cohort_Course_Section__c> cs : labMap.values()) {
			freeLabs.addAll(cs);
			cmap.put('labs', freeLabs);
		}


		//delete the original schedules associated to the cohort that has not been flagged as Selected
		try {
			delete[SELECT Id FROM Cohort_Schedule__c WHERE Cohort__c =: cohort.Id AND Selected_Schedule__c = FALSE];
		}
		catch (Exception e) {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'Could not delete old schedules, please try again.'));
			return null; 
		}

		createSchedule ( new List<Set<Cohort_Course_Section__c>> ( cmap.values() ), new List<Cohort_Course_Section__c> () );
		Boolean success = false; 
		if(goodSections != null && goodSections.size() >0) {
			success =createObjects();
		}

		if(success) {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.INFO,'Schedules Successfully Created!'));
		}
		else {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'Unable to properly create the schedules for this Cohort'));
		}

		return null;
	}

	//recursively build the schedule permutations
	public void createSchedule ( List<Set<Cohort_Course_Section__c>> temp, List<Cohort_Course_Section__c> buffer){
        
        if ( temp.size () > 0 ) {
                Set<Cohort_Course_Section__c> items = temp.remove (0);

                for ( Cohort_Course_Section__c item : items ) {
                        List<Cohort_Course_Section__c> rcis = new List<Cohort_Course_Section__c> ( buffer );
                        rcis.add ( item );
                        //look for any associated labs
                        Cohort_Course_Section__c lab = labByCourseSection.get(item.Id);
                        if(lab!=null) rcis.add(lab);
                        createSchedule( new List<Set<Cohort_Course_Section__c>> (temp), rcis );
                }
        }
        else {
        		//System.debug('@buffer: ' + buffer);
                List<String> strings = new List<String> ();
                Map<String, List<Slot>> timeSlotsByDay = new Map<String, List<Slot>>(); 
                //loop through collection of Course Sections to create time slots to use in Sort.
                for ( Cohort_Course_Section__c cs : buffer ) {
                	if(cs.Days__c != null && (!cs.Days__c.equalsIgnoreCase('ARR') && cs.Start_Time__c != null && cs.End_Time__c != null)) {
	                	String section = (cs.Section__c != null ? cs.Section__c : 'NA');
	                	String classDescription = cs.Cohort_Course__r.Name + '(Section ' + section +  '): ' + cs.Days__c + (cs.Days__c.equalsIgnoreCase('ARR') ?  '' : ' from ' + cs.Start_Time__c + ' to ' + cs.End_Time__c);
	                	if(cs.Lab_Section__c) classDescription += '(Lab)';
	                	strings.add (classDescription);
	                	String[] days; 
	                	//Ignore ARR courses as they do not have scheduled days
	                	if(!cs.Days__c.equalsIgnoreCase('ARR')) days = cs.Days__c.split('');
	                	//system.debug('@days array: ' + days); 
	                	if(days != null && days.size()>0) {
					        days.remove(0);
				    		for(String d: days) {
				    			List<Slot> slots = timeSlotsByDay.get(d);
				    			if( slots == null) slots = new List<Slot>(); 
								Slot s = new Slot(d, integer.valueOf(cs.Start_Time__c.remove(':')), integer.valueOf(cs.End_Time__c.remove(':'))); 
								//system.debug('@slot ' + s);
				    			slots.add(s);
				    			timeSlotsByDay.put(d, slots);
				    		}
				    	}
	                }
                }

                Boolean discard = FALSE; 
                //system.debug('@timeSlotsByDay ' + timeSlotsByDay);  
                //go through timeslots to check for overlapping courses. Discard the schedules where courses overlap
                for( String s : daysKey) {
                	List<Slot> timeSlots = timeSlotsByDay.get(s.toUpperCase());
                	//System.debug('@timeslots ' + timeSlots);
                	if(timeSlots != null && timeSlots.size() > 0) {
                		try {
                			timeSlots.sort(); 
                		}
                		catch (SException e) {
                			discard = TRUE; 
                			break; 
                		}
                	}
                }

                String scheduleOverview =  + String.join ( strings, ', <br>' );
                //instantiate the schedule object for those that that have passed validation
                if(!discard) {
                	List<SObject> objects = new List<SObject>();
                	Cohort_Schedule__c schedule = new Cohort_Schedule__c(Name = 'Schedule for ' + selectedSemester + '-' + selectedYear + ' (' + String.valueOf(scheduleCount) + ')',
												Cohort__c = cohort.Id, 
												Semester__c = selectedSemester,
												Year__c = selectedYear,
												Schedule_Overview__c = scheduleOverview);
					objects.add(schedule);
					for(Cohort_Course_Section__c cs: buffer) {
						objects.add((SObject)cs);
					}
					//put schedule and its associated sections in a map
                	goodSections.put(scheduleCount, objects);
                	scheduleCount ++; 
                } 
        }
	}

	public  Boolean createObjects(){

		List<Cohort_Schedule__c> schedules = new List<Cohort_Schedule__c>(); 
		List<SObject> objs = new List<SObject>(); 
		//loop through collection of SObjects and grab first object in list. This should be our schedule object
		for(Integer i = 1; i < scheduleCount; i++) {
			objs = goodSections.get(i); 
			if(objs != null){
				//system.debug('@map objs' + objs[0]);
				schedules.add((Cohort_Schedule__c)objs[0]);
				goodSections.put(i, objs);
			}

		}

		try {
			insert(schedules); 	
		}
		catch(Exception e) { 
			return false; 
		}

		List<Cohort_Scheduled_Course__c> scheduledCourses = new List<Cohort_Scheduled_Course__c>(); 
		//List<Cohort_Block_Registration__c> blockRegistrations = new List<Cohort_Block_Registration__c>(); 
		//loop through the list of SObjects and create the individual Schedule Courses and Block registration objects based on the Course Sections
		for(Integer i=1; i < scheduleCount; i++) {	
			objs =goodSections.get(i);
			if (objs != null) {
				Cohort_Schedule__c sched = (Cohort_Schedule__c)objs.remove(0);
				for(SObject so : objs) {
					Cohort_Course_Section__c cs = (Cohort_Course_Section__c)so;
					Cohort_Scheduled_Course__c sc = new Cohort_Scheduled_Course__c(Name = cs.Cohort_Course__r.Name, 
																					Cohort_Schedule__c = sched.Id,
																					Cohort_Course_Section__c = cs.Id);
					scheduledCourses.add(sc);

					//for(Contact c : students) {
					//	Cohort_Block_Registration__c br = new Cohort_Block_Registration__c(Student__c = c.Id,
					//																		Cohort_Course_Section__c = cs.Id,
					//																		Cohort_Schedule__c = sched.Id,
					//																		Cohort__c = cohort.Id);

					//	blockRegistrations.add(br);
					//}
				}
			}
		}

		try {
			insert(scheduledCourses);
			//insert(blockRegistrations);
		}
		catch(Exception e) {
			return false; 
		}

		return true; 

	}


	public class SException extends Exception { }

	public class Slot implements Comparable {
        public final Integer startTime;
        public final Integer endTime;
        public final String day;

        public Slot ( String d, Integer t1, Integer t2 ) {
                
                this.startTime = t1;
                this.endTime = t2;
                this.day = d;
        }

        public Integer compareTo ( Object so ) {
                Slot s = (Slot) so;
                //system.debug(s + '; Start Time: ' + startTime + '; End Time: ' + endTime );
                if ( endTime <= s.startTime ) return ( - 1 );
                if ( startTime >= s.endTime ) return ( + 1 );

                throw new SException ();
        }
	}

}