public with sharing class CohortCourseSectionUploadController {

	//public final static String FILE_NAME = 'Cohort Course Sections.csv';
	//public final static String FILE_DEV_NAME = (!Test.isRunningTest() ? 'CohortCourseSections_csv' : 'CohortCourseSections_test');
	public final static String FOLDER_NAME = 'Cohort Section Course Files';
	public final static String FOLDER_DEV_NAME = 'Cohort_Section_Course_Files';
	public final static String FILE_POSTFIX_STR = '_CCS_IMPORT_CSV';

	private Id folderId;
	
	public Document doc {get; set;}
	public boolean configurationError {get; set;}
	public boolean fileExists {get; set;}
	public String fileName {get; set;}
	public boolean fileFound {get; set;}
	public Id existingDocId;

	public CohortCourseSectionUploadController() {
		fileFound = false;
		List<Document> cohortSectionDocs = [
			SELECT Id, FolderId, Name, DeveloperName, Body 
			FROM Document 
			WHERE DeveloperName LIKE : ('%' + FILE_POSTFIX_STR)
				AND Keywords = NULL
		];
		System.debug('@debug cohortSectionDocs: '  + cohortSectionDocs);

		if (cohortSectionDocs != null && !cohortSectionDocs.isEmpty()) {
			fileExists = true;
		}

		doc = new Document();
	}

	public void onload() {
		List<Folder> folderList = [SELECT Id FROM Folder WHERE DeveloperName =: FOLDER_DEV_NAME];
		if (folderList == null || folderList.isEmpty()) {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,
				'No folder with the name "' + FOLDER_NAME + '" was found. Please create this folder first.'));
			configurationError = true;
		}
		else {
			configurationError = false;
			folderId = folderList[0].Id;
		}
	}

	public String getFolderName() {
		return FOLDER_NAME;
	}

	public PageReference gotoCourseCreation() {
		return Page.CohortCourseSectionCreation;
	}

	public PageReference standardUpload() {
		return upload(false);
	}

	public PageReference overwriteUpload() {
		return upload(true);
	}

	public PageReference upload(Boolean overwrite) {
		if (doc.Body == null) {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,
					'No file was selected to upload.'));
			return null;
		}
		else if (fileName == null || fileName.trim() == '') {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,
					'Please provide a file name.'));
			return null;
		}

 		System.debug('Overwrite? ' + overwrite);
 		System.debug('Standard file name: ' + fileName);
 		String devFileName = fileName.replaceAll('[^a-zA-Z0-9]', '_');
		devFileName = devFileName.replaceAll(' ', '_');
		devFileName += FILE_POSTFIX_STR;
 		System.debug('Developer File Name: ' + devFileName);

 		//check to see if file already exists
 		if (overwrite == false) {
 			System.debug('Checkeing for a document with the same dev name...');
	 		List<Document> cohortSectionDocs = [SELECT Id, FolderId, Name, DeveloperName, Body FROM Document WHERE DeveloperName =: devFileName];
			if (cohortSectionDocs != null && !cohortSectionDocs.isEmpty()) {
				//document was found, need to alert the user to verify and overwrite
				System.debug('Found a document. Warning user');
				ApexPages.addMessage(new ApexPages.message(ApexPages.severity.WARNING,
					'A file with that name already exists. Please update the name of verify that you want to overwrite the file.'));
				fileFound = true;
				existingDocId = cohortSectionDocs[0].Id;
				return null;
			}
 		}
		
		doc.AuthorId = UserInfo.getUserId();
		doc.FolderId = folderId;
		doc.DeveloperName = devFileName;
		doc.Name = fileName;
		doc.Type = 'csv';
	 
		try {
			if (overwrite == false) {
				insert doc;
			}
			else {
				doc.Id = existingDocId;
				update doc;
			}

			fileExists = true;
		} 
		catch (DMLException e) {
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'Error uploading file: ' + e));
			return null;
		}
		finally {
			doc.body = null; // clears the viewstate
			doc = new Document();
		}
		
	 	
	 	ApexPages.addMessage(new ApexPages.message(ApexPages.severity.CONFIRM,'File uploaded successfully'));
		
		return null;
  	}
}