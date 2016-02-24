@isTest
private class CohortClassSchedulerControllerTest {
	
	public static TestDataFactory tdf = new TestDataFactory(); 

	//testing CohortClassController
	@isTest 
	static void test_method_one() {
		Test.startTest();
		
		Cohort__c testCohort = tdf.createCohorts(1)[0];
		insert testCohort;
		
		Cohort_Course__c testCourse = tdf.createCourses(1)[0];
		insert testCourse;

		List<Cohort_Course_Section__c> testSections = tdf.createSections(3, testCourse.Id, 'Fall', '2016');
		insert testSections; 

		Cohort_Learning_Plan__c testLearningPlan = tdf.createLearningPlans(1, testCohort.Id)[0];
		insert testLearningPlan; 

		List<Cohort_Semester_Course__c> testCourses = tdf.createSemesterCourses(1, testLearningPlan.Id, testCourse.Id, 'Fall', '2016');
		insert testCourses;

		insert tdf.createContacts(3, '', testCohort.Id);

		ApexPages.StandardController sc = new ApexPages.StandardController(testCohort);
        CohortClassSchedulerController testController = new CohortClassSchedulerController(sc);
        
        PageReference pageRef = Page.CohortClassScheduler;
        pageRef.getParameters().put('id', String.valueOf(testCohort.Id));
        Test.setCurrentPage(pageRef);
        testController.selectedSemester = 'Fall';
        testController.selectedYear = '2016';
        pageRef = testController.getCourseSections();


        Test.stopTest();
	}
	
	//testing CohortCourseSectionUploadController
	@isTest(SeeAllData=TRUE)
	static void test_method_two() {
		Test.startTest();

		CohortCourseSectionUploadController testController = new CohortCourseSectionUploadController(); 
		String folderName = testController.getFolderName(); 
		PageReference pr = testController.gotoCourseCreation();
		testController.onload(); 
		pr = testController.standardUpload();
		Blob theBlob = Blob.valueOf('Hello World');
		testController.doc.Body = theBlob;
		testController.standardUpload();
		testController.fileName = 'Hello World';
		testController.standardUpload();

		testController.doc.Body = theBlob;
		testController.standardUpload();
		pr = testController.overwriteUpload(); 
		
		Test.stopTest(); 
	}

	//testing CohortCourseSectionCreationController
	@isTest(SeeAllData=true)
	static void testCohortCourseSectionCreationController() {
		

		String testString = 'testBlob';
		Blob b = Blob.valueOf(testString); 
		Document d = new Document(
			Name = 'Test Document',
			DeveloperName = 'Test_Document' + CohortCourseSectionUploadController.FILE_POSTFIX_STR,
			Body = b,
			FolderId = UserInfo.getUserId()
		);
		insert d;
		
		Cohort_Course__c cc = new Cohort_Course__c(
			Course_Subject__c = 'Test Subject',
			Course_Number__c = '123'
		);
		insert cc;

		Cohort_Course_Section__c cSection = new Cohort_Course_Section__c(
			Name = 'Test Section',
			Cohort_Course__c = cc.Id,
			Modified__c = true
		);
		insert cSection;
		
		Test.startTest();
			CohortCourseSectionCreationController controller = new CohortCourseSectionCreationController();
			CohortCourseSectionCreationController.getFileInformation(); 
			CohortCourseSectionCreationController.createCourseSections('2016', 'Fall');
			CohortCourseSectionCreationController.checkStatus('12345');
			CohortCourseSectionCreationController.checkModifiedRecords('2016', 'Fall');
		Test.stopTest(); 
	}

	@isTest 
	static void testLearningPlanCreation() {
		Test.startTest();
		
		Cohort_Learning_Plan_Template__c testTemplate = new Cohort_Learning_Plan_Template__c();
		testTemplate.Name = 'test';
		testTemplate.Starting_Semester__c = 'Fall';
		insert testTemplate; 

		Cohort_Semester_Template__c semTemplate = tdf.createSemesterTemplates(1, testTemplate.Id)[0];
		insert semTemplate;

		Cohort_Course__c testCourse = tdf.createCourses(1)[0];
		insert testCourse;

		List<Cohort_Course_Template__c> courseTemplates = tdf.createCourseTemplates(3, semTemplate.Id, testCourse.Id);
		insert courseTemplates; 

		Cohort__c testCohort = tdf.createCohorts(1)[0];
		testCohort.Starting_Year__c = '2016';
		testCohort.Starting_Semester__c = 'Fall';
		testCohort.Cohort_Learning_Plan_Template__c = testTemplate.Id; 
		insert testCohort;

		List<Cohort_Course_Section__c> testSections = tdf.createSections(3, testCourse.Id, 'Fall', '2016');
		insert testSections; 

		ApexPages.StandardController sc = new ApexPages.StandardController(testCohort);
        LearningPlanCreationController testController = new LearningPlanCreationController(sc);
        
        PageReference pageRef = Page.LearningPlanCreation;
        pageRef.getParameters().put('id', String.valueOf(testCohort.Id));
        Test.setCurrentPage(pageRef);
        pageRef = testController.createLearningPlan();

        Test.stopTest();
	}

	//testing CohortCourseSectionCreationController
	@isTest //(SeeAllData=TRUE)
	static void testImportCSVJob() {
		Test.startTest();
		List<String> headerLabels = new List<String> {
			'Days__c', 'Faculty__c', 'Section__c', 'Start_Time__c', 'End_Time__c', 'CRN__c', 
			'Subject__c', 'Number__c'
		};

		List<String> mappingKeys = new List<String>{'Subject__c', 'Number__c'};
		List<String> externalIdFields = new List<String>{'CRN__c', 'Days__c'};

		List<Cohort_Course__c> courses = new List<Cohort_Course__c>();
		for (Integer i = 0; i < 50; i++) {
			courses.add(new Cohort_Course__c(
				Name = 'Hello World ' + i,
				Course_Subject__c = 'CST',
				Course_Number__c = String.valueOf(i)
			));
		}
		System.debug('All the Courses: ' + courses);
		insert courses;

		List<Cohort_Course_Header_Mapping__c> mappings = new List<Cohort_Course_Header_Mapping__c>();
		for (String headerValue : headerLabels) {
			Cohort_Course_Header_Mapping__c mapping = new Cohort_Course_Header_Mapping__c(
				Header_Value__c = headerValue,
				Object_API_Name__c = 'Cohort_Course_Section__c',
				Object_API_Field_Name__c = headerValue,
				Check_for_Changes__c = true
			);

			if (headerValue == 'Subject__c') {
				mapping.Key__c = true;
				mapping.Key_Position__c = 1;
			}
			else if (headerValue == 'Number__c') {
				mapping.Key__c = true;
				mapping.Key_Position__c = 2;
			}

			if (headerValue == 'CRN__c') {
				mapping.External_Id__c = true;
				mapping.Check_for_Changes__c = false;
				mapping.External_Id_Position__c = 1;
			}
			else if (headerValue == 'Days__c') {
				mapping.External_Id__c = true;
				mapping.External_Id_Position__c = 2;
			}

			System.debug('Mapping: ' + mapping);
			mappings.add(mapping);
		}
		insert mappings;
		
		ImportCSVJob job = new ImportCSVJob('Cohort_Course_Section__c', '2016', 'Fall', 
				CohortCourseSectionUploadController.FOLDER_DEV_NAME, mappingKeys, externalIdFields);
		
		List<List<String>> csvRecords = new List<List<String>>();
		List<String> keys = new List<String>();
		csvRecords.add(headerLabels);
		for(Integer i = 0; i < 10; i++){
			String key = String.valueOf(Integer.valueOf(Math.random()*10000));
			List<String> data = new List<String>{
				'MWF',
				'Test',
				String.valueOf(i),
				String.valueOf(Datetime.now().time()),
				String.valueOf((Datetime.now().addHours(1)).time()),
				key,
				'CST',
				String.valueOf(i)
			};
			keys.add(key);
			csvRecords.add(data);
		}

		System.debug('csvRecords: ' + csvRecords);
		//Database.executeBatch(job, 200);
		job.import(csvRecords);

		csvRecords = new List<List<String>>();
		csvRecords.add(headerLabels);
		for(Integer i = 0; i < 10; i++){
			String key = keys[i];
			List<String> data = new List<String>{
				'MWF',
				'Test',
				String.valueOf(i+1),
				String.valueOf(Datetime.now().time()),
				String.valueOf((Datetime.now().addHours(2)).time()),
				key,
				'CST',
				String.valueOf(i+1)
			};
			System.debug(data);
			csvRecords.add(data);
		}
		job.import(csvRecords);

		Test.stopTest(); 
	}

	//Test CSVReader
	@isTest
	static void readIETFRFC4180CSVValueTest() {
		String data = null;  // Placeholder for data to use in testing.
		String testString = 'testBlob';
		Blob b = Blob.valueOf(testString); 
		CSVReader r = new CSVReader(); 

		System.debug(data = CSVReader.ParserCRLF);
		new CSVReader.CSVValue('', false, CSVReader.ParserCRLF).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = '""' + CSVReader.ParserCRLF);
		new CSVReader.CSVValue('', true, CSVReader.ParserCRLF).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = '"",asdf' + CSVReader.ParserCRLF);
		new CSVReader.CSVValue('', true, CSVReader.ParserCOMMA).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = ',asdf' + CSVReader.ParserCRLF);
		new CSVReader.CSVValue('', false, CSVReader.ParserCOMMA).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = '"' + CSVReader.ParserCRLF + '",blah' + CSVReader.ParserCRLF);
		new CSVReader.CSVValue(CSVReader.ParserCRLF, true, CSVReader.ParserCOMMA).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = '"""marty""","""chang"""' + CSVReader.ParserCRLF);
		new CSVReader.CSVValue('"marty"', true, CSVReader.ParserCOMMA).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = '"com""pli""cate' + CSVReader.ParserCRLF + 'd"'
				+ CSVReader.ParserCRLF);
		new CSVReader.CSVValue('com"pli"cate' + CSVReader.ParserCRLF + 'd', true, CSVReader.ParserCRLF).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));
		
		System.debug(data = 'asdf' + CSVReader.ParserCRLF);
		new CSVReader.CSVValue('asdf', false, CSVReader.ParserCRLF).assertEquals(CSVReader.readIETFRFC4180CSVValue(data));

		CSVReader.readIETFRFC4180CSVFile(b);
	}
	
}