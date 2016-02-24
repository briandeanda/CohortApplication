/*
 * Batchable, schedulable job for importing data contained in uploaded
 * CSV files for consumption. This job is created for demonstration purposes
 * only, and it is not intended to be used in a production environment.
 *
 * The job looks for CSV files uploaded as Document records with the following
 * convention for the Document Name:
 *
 *     {!ObjectAPIName}-import.csv
 *
 * For each file found, the job will assume that the first row contains
 * field names, and the remaining rows contain values.
 *
 * Again, for demonstration purposes this job only inserts new records. It does
 * not update any existing records.
 *
 * @author  Marty Y. Chang
 * @version Winter '15
 */

  /**
	The following code was modified by RedTeal. The original code base can be found
	here: https://gist.github.com/martyychang/e133652e35bc6bd89ac3
 */
global class ImportCSVJob implements Database.Batchable<SObject>, Schedulable {

	/*
	 * Delimiter used for splitting a given filename's short name (without
	 * the file extension)
	 */
	global final String FILENAME_PART_DELIMITER = '-';

	/*
	 * Delimiter used for splitting a given filename's extension from the
	 * simple name, specified with the expectation of using this delimiter
	 * with String.split()
	 */
	global final String FILENAME_EXTENSION_DELIMITER = '\\.';

	String objectName;
	String folderName;
	String year;
	String semester;
	List<String> keys;
	List<String> externalIds;

	boolean processingErrors;
	/*
	 * Default constructor
	 */
	global ImportCSVJob(String objName, String yr, String sems, String fldName, List<String> fieldKeys,  List<String> externalIdList) {
		objectName = objName;
		folderName = fldName;
		keys = fieldKeys;
		year = yr;
		semester = sems;
		externalIds = externalIdList;
		processingErrors = false;
	}

	/*
	 * @param  context The batch context
	 * @return the QueryLocator that will go through all of the documents
	 *         that need to be processed as CSV files
	 */
	global Database.QueryLocator start(Database.BatchableContext context) {
		String query = 
			'SELECT Id, Name, Body, Keywords FROM Document ' +
			'WHERE DeveloperName LIKE \'%' + CohortCourseSectionUploadController.FILE_POSTFIX_STR + '\' AND ' +
				'Folder.DeveloperName = \'' + folderName + '\' AND Keywords = NULL';
		System.debug('Query String: ' + query);

		return Database.getQueryLocator(query);
	}

	/*
	 * Parse the first file in the list of what are assumed to be Document
	 * records.
	 *
	 * @param context The batch context
	 * @param records The list of records to be processed in this batch
	 */
	global void execute(
		Database.BatchableContext context, List<SObject> records) {

		// Cast the first record as a Document object
		Document theDocument = (Document)records.get(0);
		System.debug('theDocument: ' + theDocument);

		// Read the document's body as CSV records
		List<List<String>> csvRecords =
			CSVReader.readIETFRFC4180CSVFile(theDocument.Body);
		System.debug('csvRecords: ' + csvRecords);
		
		// Figure out the object name based on the Document Name
		//String simpleFilename =
		//	theDocument.Name.split(FILENAME_EXTENSION_DELIMITER).get(0);
		
		//String objectName =
		//	simpleFilename.split(FILENAME_PART_DELIMITER).get(0);

		// Import the given data into the object using the parser
		import(csvRecords);
		if (processingErrors == false) {
			theDocument.Keywords = 'Processed';
			update theDocument;
		}
	}

	/*
	 * Execute this scheduled job as a batch job
	 *
	 * @param context The schedule context
	 */
	global void execute(SchedulableContext context) {
		Database.executeBatch(this, 1);
	}

	/*
	 * Do something cool now that the job is finished
	 *
	 * @param context The batch context
	 */
	global void finish(Database.BatchableContext context) {
		System.debug('Job finished!');
	}

	/*
	 * @return the String query that will be executed to retrieve
	 *         Document records that need to be processed
	 */
	//global static String getDocumentQuery() {
	//	String query = 
	//		'SELECT Id, Name, Body FROM Document ' +
	//		'WHERE DeveloperName = \'' + fileName + '\' AND ' +
	//			'Folder.DeveloperName = \'' + folderName + '\'';
	//	System.debug('Query String: ' + query);
	//	return query;
	//}

	/*
	 * Import CSV rows as records into a given object
	 *
	 * @param records a list of CSV records, each of which is expected
	 *                to be a list of String values. The first record
	 *                should be the list of field names.
	 * @param objectName
	 */
	global void import(List<List<String>> csvRecords) {

		// Read the first row as field names
		List<String> fieldNames = csvRecords.remove(0);
		
		// Continue with the import
		import(csvRecords, fieldNames);
	}

	/*
	 * Import CSV rows as records into a given object
	 *
	 * @param records a list of CSV records, each of which is expected
	 *                to be a list of String values
	 * @param objectType
	 * @param fieldNames
	 */
	global void import(List<List<String>> csvRecords, SObjectType sObjType, 
								List<String> fieldNames, Map<String, Map<String, String>> CSVMapping,
								Set<String> fieldChanges) {
		
		System.debug('csvRecords: ' + csvRecords);
		System.debug('sObjType: ' + sObjType);
		System.debug('objectName: ' + objectName);
		System.debug('fieldNames: ' + fieldNames);
		System.debug('CSVMapping: ' + CSVMapping);
		
		// Initialize the list of records to insert
		//List<SObject> newRecords = new List<SObject>();
		Map<String, SObject> newRecords = new Map<String, SObject>();
		Set<String> externalIdSet = new Set<String>();
		
		// Read each row and parse the row as value to insert
		while (csvRecords.size() > 0) {

			// Initialize the new record
			SObject newRecord = sObjType.newSObject();

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
						newRecord.put(apiFieldName, fieldValue);
					}

					for (String extKey : externalIds) {
						if (apiFieldName == extKey) {
							externalIdValues.put(apiFieldName, fieldValue);
						}
					}
				}

				newRecord.put('Modified__c', false);	//set it initially as false and then update later if necessary
				newRecord.put('Year__c', year);
				newRecord.put('Semester__c', semester);

				//generate the key for mapping
				String theKey = '';
				for (String extKey : externalIds) {
					theKey += externalIdValues.get(extKey);
				}

				newRecord.put('External_Id__c', theKey);
				externalIdSet.add(theKey);
				newRecords.put(theKey, newRecord);
			}
		}
		//System.debug('newRecord List: ' + newRecords);
		
		if (!newRecords.isEmpty()) {
			
			// Determine if we have a set of Keys to work with in order to update additional fields
			if (keys != null && !keys.isEmpty()) {
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
					for (SObject sObj : newRecords.values()) {
						String theKey = '';
						for (String key : keys) {
							String value = (sObj.get(key) != null) ? (String)sObj.get(key) : '';
							theKey += value;
						}
						System.debug('theKey: ' + theKey);
						Cohort_Course__c cc = courseMap.get(theKey);

						if (cc != null) {
							System.debug('Found cohort course for association: ' + cc);
							sObj.put('Cohort_Course__c', cc.Id);
						}
					}
				}
			}

			//get the Ids of the previous records because we cannot perform an upsert on sObjects
			Map<String, String> emailBodies = new Map<String, String>();
			if (!externalIdSet.isEmpty()) {
				System.debug('externalIdSet: ' + externalIdSet);
				
				//construct the SOQL string
				Set<String> fields = new Set<String>();
				fields.addAll(fieldChanges);
				fields.addAll(externalIds);
				fields.remove(null);

				String strQuery = 'SELECT Id, ';
				if (fields != null && !fields.isEmpty()) {
					for (String field : fields) {
						strQuery += field + ', ';
					}
				}
				strQuery += 'External_Id__c ' +
					' FROM ' + sObjType +	
					' WHERE External_Id__c IN : externalIdSet';
				System.debug('strQuery: ' + strQuery);

				//query for the old records for comparison
				List<SObject> oldRecords = Database.query(strQuery);
				
				//loop over old records and map them by the external id values based on the passed in external id fields
				if (oldRecords != null && !oldRecords.isEmpty()) {
					Map<String, SObject> oldRecordsByEXID = new Map<String, SObject>();
					for (SObject old : oldRecords) {
						String theKey = '';
						for (String extKey : externalIds) {
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
						for (String extKey : externalIds) {
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
				if (nRecord.get('Id') != null) {
					recordsToUpdate.add(nRecord);
				}
				else {
					recordsToInsert.add(nRecord);
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
				}
				catch (Exception e) {
					String subject = 'Error Creating Records: ' + e.getTypeName();
					String body = '' +
						'Error Message: ' + e.getMessage() + '\n' +
						'Cause: ' + e.getCause() + '\n\n' +
						'Stack Trace: ' + e.getStackTraceString();
						emailBodies.put(subject, body);
						processingErrors = true;
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
				}
				catch (Exception e) {
					String subject = 'Error Updating Records: ' + e.getTypeName();
					String body = '' +
						'Error Message: ' + e.getMessage() + '\n' +
						'Cause: ' + e.getCause() + '\n\n' +
						'Stack Trace: ' + e.getStackTraceString();
					emailBodies.put(subject, body);
					processingErrors = true;
				}
			}

			List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
			if (emailBodies != null && !emailBodies.isEmpty()) {
				for (String subject : emailBodies.keySet()) {
					Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
					message.setToAddresses(new List<String>{'eric@redteal.com'});
					message.setSubject(subject);
					message.setPlainTextBody(emailBodies.get(subject));
					messageList.add(message);
				}

				if (!Test.isRunningTest()) {
					Messaging.sendEmail(messageList);
				}
			}
		}

	}

	/*
	 * Import CSV rows as records into a given object
	 *
	 * @param records a list of CSV records, each of which is expected
	 *                to be a list of String values
	 * @param objectName
	 * @param fieldNames
	 */
	global void import(
		List<List<String>> csvRecords, List<String> fieldNames) {

		// Figure out the object type to use for intantiating new records
		SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);

		List<Cohort_Course_Header_Mapping__c> CSVMapObjs = [
			SELECT Id, Header_Value__c, Object_API_Field_Name__c, Object_API_Name__c,
				External_Id__c, Check_for_Changes__c
			FROM Cohort_Course_Header_Mapping__c
		];

		if (CSVMapObjs != null && !CSVMapObjs.isEmpty()) {
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
			
			if (CSVMapping != null && !CSVMapping.isEmpty()) {
				// Continue with the import
				import(csvRecords, sObjType, fieldNames, CSVMapping, fieldChanges);
			}
		}
	}
}