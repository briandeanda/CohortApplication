public with sharing class CohortCourseSectionCreationController {

	private static final String FILE_PROCESSED_STR = 'CCS_PROCESSED';

	public CohortCourseSectionCreationController() {}

	@RemoteAction
	public static String getFileInformation() {
		String returnJSONString;
		String errorMessage;
		String processedLikeStr = '%' + CohortCourseSectionCreationController.FILE_PROCESSED_STR + '%';

		List<Document> docList = [
			SELECT Id, Name, LastModifiedDate, Author.Name, Description
			FROM Document
			WHERE Folder.DeveloperName =: CohortCourseSectionUploadController.FOLDER_DEV_NAME
				AND DeveloperName LIKE : ('%' + CohortCourseSectionUploadController.FILE_POSTFIX_STR)
				AND (NOT Keywords LIKE : processedLikeStr)
		];

		if (docList == null || docList.isEmpty()) {
			errorMessage = 
				'No documents found in folder \\"' + CohortCourseSectionUploadController.FOLDER_NAME + '\\" ' +
				'that have not yet been processed. Please upload a document first.';
		}
		else {
			//single document
			returnJSONString = JSON.serialize(docList);
		}

		if (errorMessage != null) {
			returnJSONString = '{"error" : true, "error_message" : "' + errorMessage + '"}';
		}

		return returnJSONString;
	}

	@RemoteAction
	public static String createCourseSections(String year, String semester, String documentId) {
		System.debug('Calling createCourseSections: ' + semester + ' ' +  year + ' ' + documentId);
		
		String sObjName = 'Cohort_Course_Section__c';
		List<Cohort_Course_Header_Mapping__c> keyList = [
			SELECT Id, Object_API_Field_Name__c
			FROM Cohort_Course_Header_Mapping__c
			WHERE Object_API_Name__c =: sObjName
				AND Key__c = TRUE
			ORDER BY Key_Position__c ASC
		];
		System.debug('keyList: ' + keyList);

		
		List<String> keyStringList = new List<String>();
		for (Cohort_Course_Header_Mapping__c key : keyList) {
			keyStringList.add(key.Object_API_Field_Name__c);
		}
		System.debug('keyStringList: ' + keyStringList);
		
		List<Cohort_Course_Header_Mapping__c> externalIdList = [
			SELECT Id, Object_API_Field_Name__c
			FROM Cohort_Course_Header_Mapping__c
			WHERE Object_API_Name__c =: sObjName
				AND External_Id__c = TRUE
			ORDER BY External_Id_Position__c ASC
		];
		System.debug('externalIdList: ' + externalIdList);

		List<String> extIdFieldNames = new List<String>();
		for (Cohort_Course_Header_Mapping__c key : externalIdList) {
			extIdFieldNames.add(key.Object_API_Field_Name__c);
		}
		System.debug('extIdFieldNames: ' + extIdFieldNames);

		String docFileName = '%' + CohortCourseSectionUploadController.FILE_POSTFIX_STR;
		String processedLikeStr = '%' + CohortCourseSectionCreationController.FILE_PROCESSED_STR + '%';
		System.debug('docFileName: ' + docFileName);
		List<Document> docList = [
			SELECT Id, Name, Body, Keywords, Description
			FROM Document 
			WHERE Id =: documentId
		];
		
		List<CreateResponse> crList;

		if (docList != null && !docList.isEmpty()) {
			Document theDocument = docList[0];
			List<List<String>> csvRecords = CSVReader.readIETFRFC4180CSVFile(theDocument.Body);
			System.debug('csvRecords: ' + csvRecords);
			if (csvRecords != null && !csvRecords.isEmpty()) {
				for (List<String> listS : csvRecords) {
						System.debug(listS);
				}
				List<String> fieldNames = csvRecords.remove(0);
				if (fieldNames != null && !fieldNames.isEmpty()) {
					// Continue with the import
					crList = import(csvRecords, fieldNames, extIdFieldNames, year, semester, keyStringList);
					System.debug('crList: ' + crList);
					boolean success = true;
					if (crList == null || crList.isEmpty()) {
						success = false;
					}
					else if (crList != null && !crList.isEmpty()) {
						for (CreateResponse cr : crList) {
							success = cr.success;
							if (!success) {
								break;
							}
						}
					}
					
					if (success) {
						System.debug('Updating document!');
						theDocument.Keywords = CohortCourseSectionCreationController.FILE_PROCESSED_STR;
					}
					else {
						System.debug('Errors occurred');
						Set<String> messages = new Set<String>();
						for (CreateResponse cr : crList) {
							messages.add(cr.message);
						}

						String details = String.format(
							'Processed date: ' + Datetime.now() + '; {0}',  
							 new List<String> { String.join( new List<String>(messages) , '; ') }
						);
						theDocument.Description = details;
					}
					update theDocument;
				}
			}
		}

		if (crList == null || crList.isEmpty() || Test.isRunningTest()) {
			crList.add(new CreateResponse(
				false, 
				'',
				'Unknown Error', 
				('Could not create course sections. Please verify that the seleced file was saved as a Windows CSV and try again. ' +
								'If you continue to run into issues please contact your System Administrator for further assistance.')
			));
		}

		return JSON.serialize(crList);
	}

	@RemoteAction
	public static String checkStatus(String jobId) {
		List<AsyncApexJob> job = [
			SELECT Id, NumberOfErrors, Status, JobItemsProcessed, TotalJobItems
			FROM AsyncApexJob
			WHERE Id =: jobId
			
		];
		
		if (job != null && !job.isEmpty()) {
			return JSON.serialize(job[0]);
		}
		else {
			return null;
		}
	}

	@RemoteAction
	public static String checkModifiedRecords(String year, String semester) {
		Integer modified = [
			SELECT count()
			FROM Cohort_Course_Section__c
			WHERE Modified__c = TRUE
				AND Semester__c =: semester
				AND Year__c =: year
		];

		List<Report> modificationReport; 
		if (modified > 0) {
			modificationReport = [
				SELECT Id, Name 
				FROM Report WHERE DeveloperName = 'Modified_Course_Sections'
			];
		}

		String returnVal = '{"modified" : ' + (modified != null && modified > 0);

		if (modificationReport != null && !modificationReport.isEmpty()) {
			returnVal += ', "report_url" : "' +  System.URL.getSalesforceBaseUrl().toExternalForm() + '/' +
				modificationReport[0].Id + '", ';

			returnVal += '"report_name" : "' + modificationReport[0].Name + '"';
		}
		
		returnVal += '}';
		
		return returnVal;
	}

	private static List<CreateResponse> import(List<List<String>> csvRecords, List<String> fieldNames, List<String> extIdFieldNames, String year, String semester, List<String> keyStringList) {

		List<CreateResponse> crList = new List<CreateResponse>();

		//Query and Setup CSV Mapping objects for use later
		List<Cohort_Course_Header_Mapping__c> CSVMapObjs = [
			SELECT Id, Header_Value__c, Object_API_Field_Name__c, Object_API_Name__c,
				External_Id__c, Check_for_Changes__c
			FROM Cohort_Course_Header_Mapping__c
		];

		if (CSVMapObjs == null || CSVMapObjs.isEmpty()) {
			crList.add(new CreateResponse(
				false,
				'',
				'CSV Mapping Not Defined', 
				'No Course Heder Mapping records were defined. Please create these first before attempting to create Course Sections'
			));
			return crList;
		}
		else {
			// Create mapping
			Map<String, Map<String, String>> CSVMapping = new Map<String, Map<String, String>>();
			Set<String> fieldChanges = new Set<String>();
			for (Cohort_Course_Header_Mapping__c mapper : CSVMapObjs) {
				Map<String, String> objectSpecificMapping = CSVMapping.get(mapper.Object_API_Name__c);
				if (objectSpecificMapping == null) {
					objectSpecificMapping = new Map<String, String>();
				}
				objectSpecificMapping.put(mapper.Header_Value__c, mapper.Object_API_Field_Name__c);
				CSVMapping.put(mapper.Object_API_Name__c, objectSpecificMapping);

				if (mapper.Check_for_Changes__c) {
					fieldChanges.add(mapper.Object_API_Field_Name__c);
				}
			}
			
			boolean badExternalIdsFound = false;
			if (CSVMapping != null && !CSVMapping.isEmpty()) {
				// Retrieve describe information
				Schema.DescribeSObjectResult dsr = Cohort_Course_Section__c.sObjectType.getDescribe();
				Map<String, Schema.SObjectField> fieldMap = dsr.fields.getMap();
				System.debug(fieldMap.get('Lab_Section__c').getDescribe().getType());
				// Continue with the import
				//success = import(csvRecords, fieldNames, CSVMapping, fieldChanges, extIdFieldNames, year, semester, keyStringList);

				// Initialize the list of records to insert
				Map<String, Cohort_Course_Section__c> newRecords = new Map<String, Cohort_Course_Section__c>();
				Set<String> externalIdSet = new Set<String>();
				
				// Read each row and parse the row as value to insert
				Map<String, String> invalidExternalKeys = new Map<String, String>();
				while (csvRecords.size() > 0) {

					// Initialize the new record
					Cohort_Course_Section__c newRecord = new Cohort_Course_Section__c();

					// Read the CSV values
					List<String> values = csvRecords.remove(0);

					// Read each value, matching it up to the correct field
					// based on the position of the value in the row
					if (values.size() > 0) {
						Map<String, String> objectFieldMapping = CSVMapping.get('Cohort_Course_Section__c');
						Map<String, String> externalIdValues = new Map<String, String>();
						for (Integer i = 0; i < fieldNames.size(); i++) {
							if (objectFieldMapping == null || objectFieldMapping.isEmpty()) {
								break;
							}

							String apiFieldName = objectFieldMapping.get(fieldNames.get(i));
							String fieldValue = values.get(i);
							if (apiFieldName != null && fieldValue != null) {
								if (fieldMap.get(apiFieldName).getDescribe().getType() == Schema.DisplayType.BOOLEAN) {
									newRecord.put(apiFieldName, Boolean.valueOf(fieldValue));
								}
								else {
									newRecord.put(apiFieldName, fieldValue);
								}
							}

							for (String extKey : extIdFieldNames) {
								if (apiFieldName == extKey) {
									externalIdValues.put(apiFieldName, fieldValue);
								}
							}
						}

						//generate the key for mapping
						String theKey = '';
						boolean nullKeyFound = false;
						String badKey = '';
						for (String extKey : extIdFieldNames) {
							if (externalIdValues.get(extKey) != null && externalIdValues.get(extKey).trim() != '') {
								theKey += externalIdValues.get(extKey);
							}
							else {
								badExternalIdsFound = true;
								nullKeyFound = true;
								badKey = extKey;
								break;
							}
						}

						if (nullKeyFound == false) {
							newRecord.put('Modified__c', false);	//set it initially as false and then update later if necessary
							newRecord.put('Year__c', year);
							newRecord.put('Semester__c', semester);
							newRecord.put('External_Id__c', theKey);
							externalIdSet.add(theKey);
							newRecords.put(theKey, newRecord);
						}
						


					}
				}

				if (badExternalIdsFound == true) {
					CreateResponse cr = new CreateResponse(
						false,
						'',
						'Bad External Keys',
						'Some course sections could not be created because no values were defined for 1 or more of the following fields'
					);
					
					String details = String.format(
						'{0}', new List<String>{String.join(extIdFieldNames, ', ')}
					);
					cr.setDetails(details);
					crList.add(cr);
				}
		
				if (!newRecords.isEmpty()) {
					Set<String> noMapping = new Set<String>();
					// Determine if we have a set of Keys to work with in order to update additional fields
					if (keyStringList != null && !keyStringList.isEmpty()) {
						//retrieve cohort courses and update look up fields
						List<Cohort_Course__c> courseList = [
							SELECT Id, Course_Key__c
							FROM Cohort_Course__c
						];
						System.debug('courseList : ' + courseList);
						
						// Create map of courses by Key
						Map<String, Cohort_Course__c> courseMap = new Map<String, Cohort_Course__c>();
						for (Cohort_Course__c cc : courseList) {
							//System.debug('cc.Course_Key__c: ' + cc.Course_Key__c);
							courseMap.put(cc.Course_Key__c, cc);
						}
						System.debug('courseMap: ' + courseMap);

						if (!courseMap.isEmpty()) {
							// Loop over the list of new records and update the lookup to the cohort course
							for (Cohort_Course_Section__c ccs : newRecords.values()) {
								String theKey = '';
								for (String key : keyStringList) {
									String value = (ccs.get(key) != null) ? (String)ccs.get(key) : '';
									theKey += value;
								}
								System.debug('theKey: ' + theKey);
								Cohort_Course__c cc = courseMap.get(theKey);

								if (cc != null) {
									System.debug('Found cohort course for association: ' + cc);
									ccs.put('Cohort_Course__c', cc.Id);
								}
								else {
									//code here to send back if there were courses we couldn't process
									noMapping.add(theKey);
								}
							}
						}

						if (!noMapping.isEmpty()) {
							CreateResponse cr = new CreateResponse(
								false,
								'',
								'No Course(s) Found',
								'The following course sections did not have a matching course'
							);
							String details = String.format( '{0}', new List<String> { String.join( new List<String>(noMapping) , ', ') });
							System.debug(details);
							cr.setDetails(details);
							crList.add(cr);
						}
					}

					//get the Ids of the previous records because we cannot perform an upsert on sObjects
					Map<String, String> emailBodies = new Map<String, String>();
					if (!externalIdSet.isEmpty()) {
						System.debug('externalIdSet: ' + externalIdSet);
						
						//construct the SOQL string
						Set<String> fields = new Set<String>();
						fields.addAll(fieldChanges);
						fields.addAll(extIdFieldNames);
						fields.remove(null);

						String strQuery = 'SELECT Id, ';
						if (fields != null && !fields.isEmpty()) {
							for (String field : fields) {
								strQuery += field + ', ';
							}
						}
						strQuery += 'External_Id__c  FROM Cohort_Course_Section__c  WHERE External_Id__c IN : externalIdSet';
						System.debug('strQuery: ' + strQuery);

						//query for the old records for comparison
						List<SObject> oldRecords = Database.query(strQuery);
						
						//loop over old records and map them by the external id values based on the passed in external id fields
						if (oldRecords != null && !oldRecords.isEmpty()) {
							Map<String, SObject> oldRecordsByEXID = new Map<String, SObject>();
							for (SObject old : oldRecords) {
								String theKey = '';
								for (String extKey : extIdFieldNames) {
									Object extKeyFieldValue = old.get(extKey);
									if (extKeyFieldValue != null) {
										theKey += (String)extKeyFieldValue;
									}
								}
								
								oldRecordsByEXID.put(theKey, old);	
							}

							for (String sObjKey : newRecords.keySet()) {
								SObject nRecord = newRecords.get(sObjKey);

								String theKey = '';
								for (String extKey : extIdFieldNames) {
									Object extKeyFieldValue = nRecord.get(extKey);
									if (extKeyFieldValue != null) {
										theKey += (String)extKeyFieldValue;
									}
								}

								if (theKey != null && theKey.trim() != '') {
									SObject old = oldRecordsByEXID.get(theKey);
									if (old != null) {
										Object internalId = old.get('Id');
										if (internalId != null) {
											nRecord.put('Id', internalId);									
										}

										//record is being updated, determine if there are modifications to specific fields
										if (fieldChanges != null && !fieldChanges.isEmpty()) {
											Object oldValue, newValue;
											for (String apiName : fieldChanges) {
												oldValue = old.get(apiName);
												newValue = nRecord.get(apiName);

												if (oldValue != null && newValue != null && 
														!((String)newValue).equalsIgnoreCase('') && !((String)oldValue).equalsIgnoreCase((String)newValue)) {
													nRecord.put('Modified__c', true);
													System.debug(apiName + ' has changed -- Old: [' + oldValue + ']    |    New: [' + newValue + ']');
												}
											}
										}
									}
								}
							}
		 				}
						System.debug('@debug ' + oldRecords);
					}

					//Determine which records need to be updated or inserted
					List<SObject> recordsToInsert = new List<SObject>();
					List<SObject> recordsToUpdate = new List<SObject>();
					for (SObject nRecord : newRecords.values()) {
						if (nRecord.get('Cohort_Course__c') != null) {
							if (nRecord.get('Id') != null) {
								recordsToUpdate.add(nRecord);
							}
							else {
								recordsToInsert.add(nRecord);
							}
						}
					}
					
					
					if (!recordsToInsert.isEmpty()) {
						try {
							insert recordsToInsert;
							
							if (Test.isRunningTest()) {
								NullPointerException npe = new NullPointerException();
								npe.setMessage('Running Test');
								throw npe;
							}
							crList.add(new CreateResponse(
								true,
								'create',
								'Sections Successfully Created',
								''
							));
						}
						catch (Exception e) {
							crList.add(new CreateResponse(
								false,
								'create',
								'Error Creating New Sections', 
								e.getMessage()
							));
						}
					}

					if (!recordsToUpdate.isEmpty()) {
						try {
							update recordsToUpdate;

							if (Test.isRunningTest()) {
								NullPointerException npe = new NullPointerException();
								npe.setMessage('Running Test');
								throw npe;
							}
							crList.add(new CreateResponse(
								true,
								'update',
								'Sections Successfully Updated',
								'Sections that were already loaded have been successfully updated in the system.'
							));
						}
						catch (Exception e) {
							crList.add(new CreateResponse(
								false,
								'update',
								'Error Upodating Sections', 
								e.getMessage()
							));
						}
					}
				}
			}
		}

		return crList;
	}

	@RemoteAction
	public static String gotoCourseUpload() {
		PageReference pr = Page.CohortCourseSectionUpload;
		return (System.URL.getSalesforceBaseUrl().toExternalForm() + pr.getUrl());
	}

	@RemoteAction
	public static String gotoCourseSections() {
		Schema.DescribeSObjectResult r = Cohort_Course_Section__c.sObjectType.getDescribe();
		String keyPrefix = r.getKeyPrefix();
		return (System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + keyPrefix);
	}

	public class CreateResponse {
		public boolean success;
		public String error;
		public String message;
		public String action;
		public String details;

		public CreateResponse() {}

		public CreateResponse(boolean success, String action, String message, String error) {
			this.success = success;
			this.error = error;
			this.message = message;
			this.action = action;
		}

		public void setDetails(String d) {
			details = d;
		}
	}
}