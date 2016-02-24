public with sharing class CohortClassScheduler {
	
	public static final List<String> daysKey = new List<String> {'M', 'T', 'W', 'R', 'F'}; 
	public static integer scheduleCount = 1;
	public static String semesterString = ''; 
	public static String yearString = ''; 
	public static String cohort = '';
	public static Map<Integer, List<SObject>> goodSections = new Map<Integer, List<SObject>>(); 

	public CohortClassScheduler() {}

	public CohortClassScheduler (CohortClassScheduler controller){}

	public String getID() {
		return ApexPages.currentPage ().getParameters().get('ID');
	}

	@RemoteAction
	public static String getCourseSections (String cohortID, String semester, String year) {

		semesterString = semester;
		yearString = year; 
		cohort = cohortID;

		//Grab learning plan related to the cohort based on the year/semester specified by the user
		List<Cohort_Learning_Plan__c> learningPlans = [SELECT Id, 
													  (SELECT Cohort_Course__c from Cohort_Semester_Courses__r 
													   WHERE Semester__c =: semester AND Year__c =: year)
													   FROM Cohort_Learning_Plan__c
													   Where Cohort__c =: cohortID 
													   LIMIT 1];
		
		if (learningPlans == null || learningPlans.isEmpty()) {
			System.debug('No Learning Plans were found for the specified Cohort');
			return null;
		}		 

		List<Cohort_Semester_Course__c> semsesterCourses = learningPlans[0].Cohort_Semester_Courses__r;
		if (semsesterCourses == null || semsesterCourses.isEmpty()) {
			System.debug('No Semester Courses were found for the specified semester and year');
			return null;
		}		 
       
		Set<String> courseIds = new Set<String>();
		for(Cohort_Semester_Course__c sc : semsesterCourses){
			courseIds.add(sc.Cohort_Course__c);
		}

		//grab all of the course sections related to the Cohort Courses on the returned Semester Courses
		List<Cohort_Course_Section__c> courseSections = [SELECT Id, Capacity__c, Start_Time__c, End_Time__c, Days__c, Cohort_Course__r.Name, Cohort_Course__c, Section__c
														 FROM Cohort_Course_Section__c
														 Where Cohort_Course__c IN: courseIds
														 AND Semester__c =: semester 
														 AND Year__c =: year];

		if (courseSections == null || courseSections.isEmpty()) {
			System.debug('No Course Sections were found for the specified semester and year');
			return null;
		}		 
		

		Map<Id,Set<Cohort_Course_Section__c>> cmap = new Map<Id,Set<Cohort_Course_Section__c>> ();

		for ( Cohort_Course_Section__c c : courseSections ) {
		        Set<Cohort_Course_Section__c> cs = cmap.get(c.Cohort_Course__c);
		        if( cs == null ) {
		        	cs = new Set<Cohort_Course_Section__c>();
		        }
		        cs.add(c);
		        cmap.put(c.Cohort_Course__c, cs);

		}

		createSchedule ( new List<Set<Cohort_Course_Section__c>> ( cmap.values () ), new List<Cohort_Course_Section__c> () );
		if(goodSections != null && goodSections.size() >0) {
			createObjects();
		}


		return JSON.serialize(courseSections);
	}

	public static void createSchedule ( List<Set<Cohort_Course_Section__c>> temp, List<Cohort_Course_Section__c> buffer){
        
        if ( temp.size () > 0 ) {
                Set<Cohort_Course_Section__c> items = temp.remove (0);

                for ( Cohort_Course_Section__c item : items ) {
                        List<Cohort_Course_Section__c> rcis = new List<Cohort_Course_Section__c> ( buffer );
                        rcis.add ( item );
                        createSchedule( new List<Set<Cohort_Course_Section__c>> (temp), rcis );
                }
        }
        else {
        		//System.debug('@buffer: ' + buffer);
                List<String> strings = new List<String> ();
                Map<String, List<Slot>> timeSlotsByDay = new Map<String, List<Slot>>(); 
                for ( Cohort_Course_Section__c cs : buffer ) {
                	String classDescription = cs.Cohort_Course__r.Name + '(Section ' + cs.Section__c +  '): ' + cs.Days__c + (cs.Days__c.equalsIgnoreCase('ARR') ?  '' : ' from ' + cs.Start_Time__c + ' to ' + cs.End_Time__c);
                	strings.add (classDescription);
                	String[] days; 
                	if(!cs.Days__c.equalsIgnoreCase('ARR')) days = cs.Days__c.split('');
                	//system.debug('@days array: ' + days); 
                	if(days != null && days.size()>0) {
                		days.remove(0);
                		for(String d: days) {
                			List<Slot> slots = timeSlotsByDay.get(d);
                			if( slots == null) {
                				slots = new List<Slot>(); 
                			}
							Slot s = new Slot(d, integer.valueOf(cs.Start_Time__c.remove(':')), integer.valueOf(cs.End_Time__c.remove(':'))); 
							//system.debug('@slot ' + s);
                			slots.add(s);
                			timeSlotsByDay.put(d, slots);

                		}
                	}
                }

                Boolean discard = FALSE; 
                //system.debug('@timeSlotsByDay ' + timeSlotsByDay);  
                for( String s : CohortClassScheduler.daysKey) {
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

                System.debug ( ( discard ? 'BAD' : 'GOOD' ) + ' ' + '\'' + String.join ( strings, '\', \'' ) + '\'' );
                if(!discard) {
                	List<SObject> objects = new List<SObject>();
                	Cohort_Schedule__c schedule = new Cohort_Schedule__c(Name = 'Schedule for ' + semesterString + '-' + yearString + ' (' + String.valueOf(scheduleCount) + ')',
												Cohort__c = cohort, 
												Semester__c = semesterString,
												Year__c = yearString);
					objects.add(schedule);
					
					for(Cohort_Course_Section__c cs: buffer) {
						objects.add((SObject)cs);
					}

                	goodSections.put(scheduleCount, objects);
                	scheduleCount ++; 
                } 
        }
	}

	public static void createObjects(){

		List<Cohort_Schedule__c> schedules = new List<Cohort_Schedule__c>(); 
		List<SObject> objs = new List<SObject>(); 
		for(Integer i = 1; i < scheduleCount; i++) {
			objs = goodSections.get(i); 
			if(objs != null){
				//system.debug('@map objs' + objs[0]);
				schedules.add((Cohort_Schedule__c)objs[0]);
				goodSections.put(i, objs);
			}

		}
		insert(schedules); 

		List<Cohort_Scheduled_Course__c> scheduledCourses = new List<Cohort_Scheduled_Course__c>(); 
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
				}
			}
		}

		insert(scheduledCourses);

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