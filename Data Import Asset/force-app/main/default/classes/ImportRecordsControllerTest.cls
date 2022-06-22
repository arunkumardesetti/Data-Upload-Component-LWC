/*  
     *  Class Name : ImportRecordsControllerTest
	 *  Class Description : Test class for ImportRecordsController class.
	 *  Author: Arun Kumar Desetti
	 *  Created Date: 20-06-2022(DD-MM-YYYY)
*/ 
@isTest
private class ImportRecordsControllerTest {
    //Test GetListOfObjDetails
    @isTest static void testGetListOfObjDetails(){
        ImportRecordsController.ObjectDetailsWrapper wObj = new ImportRecordsController.ObjectDetailsWrapper();
        wObj.objAPI = '';
        wObj.objLabel = 'None';
        
        test.startTest();
        List<ImportRecordsController.ObjectDetailsWrapper> objList = ImportRecordsController.getListOfObjDetails();
        test.stopTest();
        System.assertEquals(wObj.objLabel , objList[0].objLabel);
        System.assertEquals(wObj.objAPI , objList[0].objAPI);
    }
    
    //Test DownloadCsvTemplate
    @isTest static void testDownloadCsvTemplate(){
        test.startTest();
        List<String> fieldsList = ImportRecordsController.downloadCsvTemplate('Account','');
        test.stopTest();
        System.assertEquals(true , fieldsList.contains('Account Name'));
    }
    
    //Positive Test ValidateCsvFile
    @isTest static void testValidateCsvFile(){        
        String str = JSON.serialize('Status,Test External ID\r\n');
        test.startTest();
        String res = ImportRecordsController.validateCsvFile(str,'Case','Test Object');
        test.stopTest();
        System.assertEquals('Success' , res);
    }
    
    //Negative Test ValidateCsvFile
    @isTest static void testErrorValidateCsvFile(){        
        String str = JSON.serialize('Status,Wrong External ID\r\n');
        test.startTest();
        String res1 = ImportRecordsController.validateCsvFile(str,'Case','Test Object');
        String res2 = ImportRecordsController.validateCsvFile(str,'Case','');
        test.stopTest();
        System.assertEquals(true , res1.contains('Field Mismatch in Template, Error Field: Wrong External ID.'));
        System.assertEquals(true , res2.contains('Field Mismatch in Template, Error Field: Wrong External ID.'));
    }
    
    //Test ProcessCsvFile
    @isTest static void testProcessCsvFile() {
        String str = JSON.serialize('Account Name\r\n\"Hello, Test, 123\"\r\n');
        test.startTest();
        List<String> resList = ImportRecordsController.processCsvFile('TestFile',str,'Account','');
        test.stopTest();
        System.assertEquals(true , resList[0].contains('Row Number,ID,Account Name'));
        System.assertEquals(true , resList[1].contains('Row Number,Error,Account Name'));
    }
}