import { LightningElement, track, wire } from 'lwc';
import getListOfObjDetails from '@salesforce/apex/ImportRecordsController.getListOfObjDetails';
import validateCsvFile from '@salesforce/apex/ImportRecordsController.validateCsvFile';
import downloadCsvTemplate from '@salesforce/apex/ImportRecordsController.downloadCsvTemplate';
import processCsvFile from '@salesforce/apex/ImportRecordsController.processCsvFile';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

export default class ImportRecords extends LightningElement {
    @track objItems = [];
    objError;
    error = '';
    templateError = ''; 
    selectedObjValue = '';
    selectedParentObjValue = '';
    TemplateObjValue = '';
    TemplateParentObjValue = '';
    @track disableButton = true;
    @track disableTemplateButton = true;
    @track successDisableButton = true;
    @track errorDisableButton = true;
    @track showLoadingSpinner = false;
    @track uploadReport = false;
    @track fileName = '';
    filesUploaded = [];
    file;
    fileContents='';
    fileReader;
    MAX_FILE_SIZE = 1500000;
    reportSuccess = '';
    reportError = '';

    @wire
    (getListOfObjDetails) listOfObjectDetails({ error, data }) {
        if (data) {
            for (var i = 0; i < data.length; i++) {
                this.objItems = [...this.objItems,{ value: data[i].objAPI, label: data[i].objLabel }];
            }
        } else if (error) {
            this.objError = error;
            this.objects = undefined;
        }
    }

    /**
     * Return list of Objects for combobox.
     */
     get objectOptions() {
        return this.objItems;
    }

    //Upload File
    handleObjectChange(event) {
        this.selectedObjValue = event.detail.value;
    }

    handleParentObjectChange(event) {
        this.selectedParentObjValue = event.detail.value;
    }

    //Download File
    handleTemplateObjectChange(event) {
        this.TemplateObjValue = event.detail.value;
        this.disableTemplateButton = false;
    }

    handleTemplateParentObjectChange(event) {
        this.TemplateParentObjValue = event.detail.value;
    }

    // accepted parameters
    get acceptedCSVFormats() {
        return ['.csv'];
    }

    //Changing of files
    handleFilesChange(event) {
        if(event.target.files.length > 0) {
            if(event.target.files[0].name.toLowerCase().includes('.csv')){
                this.filesUploaded = event.target.files;
                this.fileName = event.target.files[0].name;
                this.error = '';
                this.reportSuccess = '';
                this.reportError = '';
                this.disableButton = false;
                this.uploadReport = false;
            } else {
                this.error = 'Please Select a CSV File.';
                this.filesUploaded = [];
                this.fileName = '';
            }
        }
    }

    handleSuccessFile(){
        this.downloadReportFile('success');
    }

    handleErrorFile(){
        this.downloadReportFile('error');
    }
    
    downloadReportFile(param){
            // Creating anchor element to download
            let downloadElement = document.createElement('a');
            var today = new Date();
            var dd = String(today.getDate()).padStart(2, '0');
            var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
            var yyyy = today.getFullYear();
            today = dd + '-' + mm + '-' + yyyy;
            // This  encodeURI encodes special characters, except: , / ? : @ & = + $ # (Use encodeURIComponent() to encode these characters).
            if(param == 'success'){
                downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(this.reportSuccess);
                // CSV File Name
                downloadElement.download = 'Success File '+today+'.csv';
            }
            if(param == 'error'){
                downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(this.reportError);
                // CSV File Name
                downloadElement.download = 'Error File '+today+'.csv';
            }
            downloadElement.target = '_self';
            
            // below statement is required if you are using firefox browser
            document.body.appendChild(downloadElement);
            // click() Javascript function to download CSV file
            downloadElement.click();
    }
 
    handleSave() {
        if(this.filesUploaded.length > 0) {
            if(this.selectedObjValue != '') {
                this.uploadHelper();
                this.error = '';
            }
            else {
                this.error = 'Please select an Object Name from the Dropdown !';
            }
        }
        else {
            this.error = 'Please select a CSV file to upload !';
        }
    }
 
    uploadHelper() {
        this.file = this.filesUploaded[0];
       if (this.file.size > this.MAX_FILE_SIZE) {
            this.error = 'File Size is too Big.';
            return ;
        }
        this.showLoadingSpinner = true;
        this.fileReader= new FileReader();
        this.fileReader.onloadend = (() => {
            this.fileContents = this.fileReader.result;
            this.validateFileTemplate();
        });
        this.fileReader.readAsText(this.file);
        this.error = '';
    }

    downloadTemplate(){
        if(this.TemplateObjValue != ''){
            downloadCsvTemplate({objectName: this.TemplateObjValue, parentObjectName:this.TemplateParentObjValue})
            .then(columnHeader => {
                console.log('columnHeader: '+columnHeader);
                let rowEnd = '\n';
                let csvString = '';
                this.templateError = '';
        
                // splitting using ','
                csvString += columnHeader.join(',');
                csvString += rowEnd;
            
                // Creating anchor element to download
                let downloadElement = document.createElement('a');

                // This  encodeURI encodes special characters, except: , / ? : @ & = + $ # (Use encodeURIComponent() to encode these characters).
                downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvString);
                downloadElement.target = '_self';
                // CSV File Name
                downloadElement.download = this.TemplateObjValue+' Template.csv';
                // below statement is required if you are using firefox browser
                document.body.appendChild(downloadElement);
                // click() Javascript function to download CSV file
                downloadElement.click();
            })
            .catch(error => {
                console.log("Error message: " + error.body.message);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error while Creating the Template',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
        }
        else {
            this.templateError = 'Please select an Object Name from the Dropdown !';
        }
    }

    validateFileTemplate(){
        validateCsvFile({fileName: this.fileName, fileData: JSON.stringify(this.fileContents), objectName: this.selectedObjValue, parentObjectName: this.selectedParentObjValue})
        .then(validateResult => {
            console.log('validateResult: '+validateResult);
            if(validateResult == 'Success'){
                this.error='';
                this.processFile();
            } else {
                this.showLoadingSpinner = false;
                this.error = validateResult;
            }
        })
        .catch(error => {
            console.log("Error message: " + error.body.message);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error while validating File',
                    message: error.body.message,
                    variant: 'error',
                }),
            );
            this.showLoadingSpinner = false;
        });
        this.disableButton = true;
    }
 
    processFile() {
        console.log('fileContents: '+JSON.stringify(this.fileContents));
        processCsvFile({fileName: this.fileName, fileData: JSON.stringify(this.fileContents), objectName: this.selectedObjValue, parentObjectName: this.selectedParentObjValue})
        .then(result => {
            console.log('result: '+result);
            console.log('result lenght: '+result.length);
            console.log('result Success: '+result[0]);
            console.log('result Error: '+result[1]);
            this.reportSuccess = result[0];
            this.reportError = result[1];
            this.uploadReport = true;
            this.successDisableButton = false;
            this.errorDisableButton = false;
            this.fileName = this.fileName + ' - Uploaded Successfully';
            this.showLoadingSpinner = false;
            this.error='';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success!!',
                    message: this.file.name + ' - Uploaded Successfully!!!',
                    variant: 'success',
                }),
            );
        })
        .catch(error => {
            console.log("Error message: " + error.body.message);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error while uploading File',
                    message: error.body.message,
                    variant: 'error',
                }),
            );
            this.showLoadingSpinner = false;
        });
        this.disableButton = true;
    } 
}