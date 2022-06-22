/*  
     *  Class Name : ImportRecordsController
	 *  Class Description : This class is used for the following processes:
                            1. download a custom created template
                            2. validate the template of a csv file which is being uploaded
                            3. process the data from a csv file which is being uploaded post validation of the template.
                            4. Create success/error report files when the upload of the records is completed.
	 *  Author: Arun Kumar Desetti
	 *  Created Date: 15-06-2022(DD-MM-YYYY)
*/ 
public class ImportRecordsController {
    
    // Method to get the object list containing Object Label and Object Api Name
    @AuraEnabled(cacheable=true)
    public static List<ObjectDetailsWrapper> getListOfObjDetails() {
        List<EntityDefinition> objectsList = [SELECT QualifiedApiName, Label FROM EntityDefinition where IsSearchable = true ORDER BY Label];
        List<ObjectDetailsWrapper> objectListWrapper = new List<ObjectDetailsWrapper>();
        ObjectDetailsWrapper oWrap = new ObjectDetailsWrapper();
        oWrap.objLabel = 'None';
        oWrap.objAPI = '';
        objectListWrapper.add(oWrap);
        for(EntityDefinition obj: objectsList){
            ObjectDetailsWrapper objWrap = new ObjectDetailsWrapper();
            objWrap.objLabel = obj.Label;
            objWrap.objAPI = obj.QualifiedApiName;
            objectListWrapper.add(objWrap);
        }
        return objectListWrapper;
    }
    
    // Wrapper class to get the Object label and Object Api name as an object
    public class ObjectDetailsWrapper {
        @AuraEnabled
        public String objLabel;
        @AuraEnabled
        public String objAPI;
    }
    
    // Method to Download the template with fields defined in custom metadata types
    @AuraEnabled
    public static List<String> downloadCsvTemplate(String objectName,String parentObjectName) {
        List<String> mdtFieldsList = new List<String>();
        Data_Upload_Template__mdt[] templateFieldsList = FetchMetaDataFields(objectName);
        Data_Upload_Template__mdt[] templateParentFieldsList = FetchParentMetaDataFields(parentObjectName);
        for(Data_Upload_Template__mdt mdtFields:templateFieldsList){
            mdtFieldsList.add(mdtFields.Label);
        }   
        for(Data_Upload_Template__mdt mdtFields:templateParentFieldsList){
            mdtFieldsList.add(mdtFields.Label);
        }   
        system.debug('mdtFieldsList: '+mdtFieldsList);
        return mdtFieldsList;
    }
    
    // Method to validate the Template being uploaded
    @AuraEnabled
    public static String validateCsvFile(String fileData,String objectName,String parentObjectName) {
        List<Data_Upload_Template__mdt> templateFieldsList = new List<Data_Upload_Template__mdt>();
        List<Data_Upload_Template__mdt> templateParentFieldsList = new List<Data_Upload_Template__mdt>();
        List<String> mdtFieldsList = new List<String>();
        Map<String,Data_Upload_Template__mdt> metadataReferenceFieldMap = new Map<String,Data_Upload_Template__mdt>();
        templateFieldsList = FetchMetaDataFields(objectName);
        If(parentObjectName !=''){
            templateParentFieldsList = FetchParentMetaDataFields(parentObjectName);
            if(templateParentFieldsList.size() > 0){
                metadataReferenceFieldMap = createMtdMap(templateParentFieldsList);
            }
        }  
        String csvFile  = JSON.deserializeUntyped(fileData).toString();
        system.debug('csvFile: '+csvFile);
        List<String> csvFileLines = csvFile.trim().split('\n');
        List<String> fieldsList = csvFileLines[0].trim().split(',');
        for(Data_Upload_Template__mdt mdtFields:templateFieldsList){
            mdtFieldsList.add(mdtFields.Label);
        }
        boolean mismatchFlag = false;
        String errorField = '';
        system.debug('fieldsList: '+fieldsList);
        system.debug('mdtFieldsList: '+mdtFieldsList);
        for(String fl:fieldsList){
            if(mdtFieldsList.contains(fl)){
                mismatchFlag = true;
            }
            else{
                If(parentObjectName !='' && metadataReferenceFieldMap.get(fl) != null && metadataReferenceFieldMap.get(fl).Object_Api_name__c == parentObjectName){
                    mismatchFlag = true;
                }
                else {
                    mismatchFlag = false;
                    errorField = fl;
                    break;
                }
            }
        }
        if(mismatchFlag == true){
            return 'Success';
        }
        else{
            if(parentObjectName == ''){
                return 'Field Mismatch in Template, Error Field: '+errorField+'.\n\n Please enter from the below specified Fields for '+objectName+' Object!\nAllowed Fields - '+String.join(mdtFieldsList, ',');
            }
            else {
                List<String> parentMtdFields = new List<String>(metadataReferenceFieldMap.keySet());
                return 'Field Mismatch in Template, Error Field: '+errorField+'.\n Please enter from the below specified Fields for '+objectName+' Object!\nAllowed Fields - '+String.join(mdtFieldsList, ',')+'\n\nFor Parent Object: '+parentObjectName+' use below External ID Fields!\nAllowed Fields - '+String.join(parentMtdFields, ',');
            }
        }
    }
    
    // Method to process the data from the csv file and return the report of success and errors on data insert
    @AuraEnabled
    public static List<String> processCsvFile(String fileName, String fileData,String objectName,String parentObjectName) {
        List<Data_Upload_Template__mdt> templateFieldsList = new List<Data_Upload_Template__mdt>();
        List<Data_Upload_Template__mdt> templateParentFieldsList = new List<Data_Upload_Template__mdt>();
        templateFieldsList = FetchMetaDataFields(objectName);
        If(parentObjectName !=''){
            templateParentFieldsList = FetchParentMetaDataFields(parentObjectName);
        }
        
        //Check and retrieve Record Types
        boolean isRecordType = false;
        List<RecordType> recordTypeList = new List<RecordType>();
        Map<String,RecordType> recordTypeMap = new Map<String,RecordType>();
        for(Data_Upload_Template__mdt field: templateFieldsList){
            If(field.Data_Type__c == 'RecordType'){
                isRecordType = true;
                break;
            }
        }
        If(isRecordType == true){
            recordTypeList = [Select ID, Name, DeveloperName, IsActive, SobjectType from RecordType where SobjectType = :objectName AND IsActive = true];
            for(RecordType rt: recordTypeList){
                recordTypeMap.put(rt.Name,rt);
            }
        }

        
        //deserialize the string
        String csvFile  = JSON.deserializeUntyped(fileData).toString();
        List<String> csvFileLines = csvFile.trim().split('\n');
        
        //seperate fields
        List<String> fieldsList = csvFileLines[0].trim().split(',');
        
        //Map Metadata Fields
        Map<String,Data_Upload_Template__mdt> metadataFieldMap = new Map<String,Data_Upload_Template__mdt>();
        metadataFieldMap = createMtdMap(templateFieldsList);
        
        //Map Parent Metadata Fields
        Map<String,Data_Upload_Template__mdt> metadataReferenceFieldMap = new Map<String,Data_Upload_Template__mdt>();
        if(templateParentFieldsList.size() > 0){
            metadataReferenceFieldMap = createMtdMap(templateParentFieldsList);
        }
        
        //Combine All Metadata Field Map
        metadataFieldMap.putAll(metadataReferenceFieldMap);
        
        //get the Lookup field details
        Data_Upload_Template__mdt metadataLookupField = new Data_Upload_Template__mdt();
        FieldDefinition lookupField = new FieldDefinition();
        if(templateParentFieldsList.size() > 0){
            metadataLookupField =[Select Label, Field_API_Name__c, Object_Api_name__c, Data_Type__c, Is_External_ID__c, Is_Lookup_Master_Detail__c, Lookup_Master_Detail_To__c from Data_Upload_Template__mdt where Is_Lookup_Master_Detail__c = true AND Lookup_Master_Detail_To__c = :parentObjectName Limit 1];
            lookupField = [SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, Label, RelationshipName, DataType FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = :objectName AND QualifiedApiName = :metadataLookupField.Field_API_Name__c Limit 1];
        }
        
        //seperate data rows for insert
        List<String> csvDataList = new List<String>();
        for(Integer i=1; i<csvFileLines.Size(); i++){
            csvDataList.add(csvFileLines[i].trim());
        }
        
        //Separating every column in a row
        List<List<String>> fieldValuesList = new List<List<String>>();
        List<List<String>> reportFieldValuesList = new List<List<String>>();
        for(String data: csvDataList){
            List<String> valuesList = new List<String>();
            List<String> rowDataList = data.split(',');
            reportFieldValuesList.add(rowDataList);
            Boolean flag = false;
            Integer z=0;
            string temp = '';
            for(String val: rowDataList){
                //for strings containing ','(comma) in between
                if(val.contains('"')){
                    flag = true;
                    z=z+1;
                    if(temp == ''){
                        temp=val;
                    }
                    else {
                        temp = temp+', '+val;
                    }
                    if(z==2){
                        z=0;
                        flag=false;
                        valuesList.add(temp.replaceAll('"', ''));
                        temp = '';
                    }
                }
                else if(flag == true && !val.contains('"')){
                    temp = temp+', '+val;
                }
                else if(flag == false && !val.contains('"')){
                    valuesList.add(val);
                }
            }
            fieldValuesList.add(valuesList);
        }
        
        //Initialize Object and create records
        List<SObject> insertList = new List<SObject>();
        List<String> stringInputs = new List<String>{'Text','Text Area','Phone','Email','URL','Lookup','Hierarchy','Master-Detail'};
        List<String> decimalInputs = new List<String>{'Currency','Percent','Number','Geolocation'};
        List<String> booleanInputs = new List<String>{'Checkbox'};
        List<String> externalInputs = new List<String>{'Text','Number','Email','Auto Number'};
        List<String> allDataTypes = new List<String>{'Date','Date/Time','Time','Picklist','RecordType'};
        allDataTypes.addAll(stringInputs);
        allDataTypes.addAll(decimalInputs);
        allDataTypes.addAll(booleanInputs);
        allDataTypes.addAll(externalInputs);
        for(List<String> str: fieldValuesList){
            sObject SObj = Schema.getGlobalDescribe().get(objectName).newSObject();
            for(Integer i=0; i<str.Size(); i++){
                if(externalInputs.Contains(metadataFieldMap.get(fieldsList[i]).Data_Type__c) && parentObjectName != '' && str[i] != '' && metadataFieldMap.get(fieldsList[i]).Is_External_ID__c == true  && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == parentObjectName){
                    sObject referenceSObj = Schema.getGlobalDescribe().get(parentObjectName).newSObject();
                    referenceSObj.put(metadataReferenceFieldMap.get(fieldsList[i]).Field_API_Name__c,str[i]);
                    SObj.putSObject(lookupField.RelationshipName, referenceSObj);
                }
                else if(stringInputs.Contains(metadataFieldMap.get(fieldsList[i]).Data_Type__c) && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,str[i]); 
                }
                else if(booleanInputs.Contains(metadataFieldMap.get(fieldsList[i]).Data_Type__c) && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,Boolean.valueOf(str[i])); 
                }
                else if(decimalInputs.Contains(metadataFieldMap.get(fieldsList[i]).Data_Type__c) && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,Decimal.valueOf(str[i])); 
                }
                else if(metadataFieldMap.get(fieldsList[i]).Data_Type__c == 'Date' && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,Date.valueOf(str[i])); 
                }
                else if(metadataFieldMap.get(fieldsList[i]).Data_Type__c == 'Date/Time' && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,DateTime.valueOf(str[i])); 
                }
                else if(metadataFieldMap.get(fieldsList[i]).Data_Type__c == 'Time' && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    String[] strTimeSplit = str[i].split(':');
                    Time timeChange = Time.newInstance( Integer.valueOf(strTimeSplit[0]),Integer.valueOf(strTimeSplit[1]),0,0);
                    SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,timeChange); 
                }
                else if(metadataFieldMap.get(fieldsList[i]).Data_Type__c == 'Picklist' && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    /*If(str[i].contains(',')){
                        SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,str[i].replace(',', ';'));
                    }
                    else {*/
                        SObj.put(metadataFieldMap.get(fieldsList[i]).Field_API_Name__c,str[i]); 
                    //}
                }
                else if(metadataFieldMap.get(fieldsList[i]).Data_Type__c == 'RecordType' && metadataFieldMap.get(fieldsList[i]).Object_Api_name__c == objectName && str[i] != ''){
                    SObj.put('RecordTypeId',recordTypeMap.get(str[i]).ID); 
                }
                else if(str[i] != '' && !allDataTypes.Contains(metadataFieldMap.get(fieldsList[i]).Data_Type__c)){
                    throw new AuraHandledException('Invalid Data Type Defined for the Field - '+fieldsList[i]+' in Custome Metadata Types.');
                }
            }
            insertList.add(sObj);
        }
        Integer count = 0;
        List<String> error = new List<String>();
        List<String> success = new List<String>();
        List<Integer> successNumbers = new List<Integer>();
        List<Integer> errorNumbers = new List<Integer>();
        system.debug('insertList size: '+insertList.size());
        Database.SaveResult[] resultList = Database.Insert(insertList, false);
        for(Database.SaveResult rl:resultList) {
            if(rl.isSuccess()) {
                success.add(rl.getId());
                successNumbers.add(count);
            }
            else {
                for(Database.Error err : rl.getErrors()) {
                    error.add(err.getMessage());
                    errorNumbers.add(count);
                }
            }
            count++;
        }
        List<String> returnString = new List<String>();
        returnString.add(createSuccessFileData(success,successNumbers,fieldsList,reportFieldValuesList));
        returnString.add(createErrorFileData(error,errorNumbers,fieldsList,reportFieldValuesList));
        return returnString;
    }
    
    // create Success file data
    public static String createSuccessFileData(List<String> success,List<Integer> successNumbers,List<String> fieldsList,List<List<String>> reportFieldValuesList) {
        String successHeader = 'Row Number,ID';
        String successReport = createReportBody(successHeader,success,successNumbers,fieldsList,reportFieldValuesList);
        return successReport;
    }
    
    // create error file data
    public static String createErrorFileData(List<String> error,List<Integer> errorNumbers,List<String> fieldsList,List<List<String>> reportFieldValuesList) {
        String errorHeader = 'Row Number,Error';
        String errorReport  = createReportBody(errorHeader,error,errorNumbers,fieldsList,reportFieldValuesList);
        return errorReport;
    }
    
    // create Success/Error file body
    public static String createReportBody(String reportHeader, List<String> report,List<Integer> reportNumbers,List<String> fieldsList,List<List<String>> reportFieldValuesList){
        for(Integer i=0;i<fieldsList.size();i++){
            if(i== fieldsList.size()-1){
                reportHeader = reportHeader+','+fieldsList[i]+'\n';
            }
            else {
                reportHeader = reportHeader+','+fieldsList[i];
            }
        }
        
        List<List<String>> reportDataList = new List<List<String>>();
        for(Integer row: reportNumbers){
            List<String> tempList = new List<String>();
            tempList.add(String.ValueOf(row+2));
            tempList.add(report[reportNumbers.indexOf(row)]);
            tempList.addAll(reportFieldValuesList[row]);
            reportDataList.add(tempList);
        }
        
        String reportBody = '';
        for(List<String> strList: reportDataList){
            for(Integer i=0;i<strList.size();i++){
                string temp = '';
                if(i==0){
                    temp = strList[i];                    
                }
                else if(i== strList.size()-1){
                    temp = temp+','+strList[i]+'\n';
                }
                else {
                    temp = temp+','+strList[i];
                }
                reportBody = reportBody+temp;
            }
        }
        String reportFinal = reportHeader+reportBody;
        return reportFinal;
    }
    
    //Create custom Metadata Type field Map<Label,Record>
    public static Map<String,Data_Upload_Template__mdt> createMtdMap(Data_Upload_Template__mdt[] templateFieldsList){
        Map<String,Data_Upload_Template__mdt> mtdFieldMap = new Map<String,Data_Upload_Template__mdt>();
        for(Data_Upload_Template__mdt dutFields:templateFieldsList){
            mtdFieldMap.put(dutFields.Label,dutFields);
        }
        return mtdFieldMap;
    }
    
    //Fetch Fields Records from Custom Metadata Type of the defined object
    public static List<Data_Upload_Template__mdt> FetchMetaDataFields(String objectName){
        return [Select Label, Field_API_Name__c, Object_Api_name__c, Data_Type__c, Is_External_ID__c, Is_Lookup_Master_Detail__c, Lookup_Master_Detail_To__c from Data_Upload_Template__mdt where Object_Api_name__c = :objectName];
    }
    
    //Fetch Fields Records from Custom Metadata Type of the defined parent object
    public static List<Data_Upload_Template__mdt> FetchParentMetaDataFields(String parentObjectName){
        return [Select Label, Field_API_Name__c, Object_Api_name__c, Data_Type__c, Is_External_ID__c, Is_Lookup_Master_Detail__c, Lookup_Master_Detail_To__c from Data_Upload_Template__mdt where Object_Api_name__c = :parentObjectName AND Is_External_ID__c = true];
    }
}