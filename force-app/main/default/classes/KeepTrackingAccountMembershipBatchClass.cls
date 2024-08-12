global class KeepTrackingAccountMembershipBatchClass implements Database.Batchable<SObject> , Schedulable{
    
    // Instance variable to store the Set of IDs
    private Set<Id> accountRecordIds;
    private Set<Id> contactRecordIds;
    
    // Constructor to initialize values
    public KeepTrackingAccountMembershipBatchClass() {
        
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        
        // Query to retrieve Contact Ids from Term changed today and yesterday by Fun Fonteva Term batch
        for (OrderApi__Renewal__c term : [select OrderApi__Account__c from  OrderApi__Renewal__c WHERE id in (SELECT ParentId FROM OrderApi__Renewal__History where (Field = 'OrderApi__Is_Active__c' or Field = 'OrderApi__Term_End_Date__c') and (CreatedDate = TODAY OR CreatedDate = YESTERDAY)) and OrderApi__Entity__c = 'account']) {
            accountIds.add(term.OrderApi__Account__c);
        }
        
        // Assign the account to the class property accountRecordIds
        this.accountRecordIds = accountIds;
        
        // Query to retrieve Contact Ids from assignement
        for (contact contact : [select id from  contact WHERE AccountId IN :accountRecordIds]) {
            contactIds.add(contact.id);
        }
        // Assign the contacts to the class property contactrecordIds
        this.contactRecordIds = contactIds;
    }
    
    public KeepTrackingAccountMembershipBatchClass(Set<Id> recordIds) {
        // Only when record is greater than 0 the block will be executed
        if(recordIds.size() > 0) {
            
            Set<Id> contactIds = new Set<Id>();
            
            // Assign the account to the class property accountRecordIds
            this.accountRecordIds = recordIds;
            
            // Query to retrieve Contact Ids from assignement
            for (contact contact : [select id from  contact WHERE AccountId IN :accountRecordIds]) {
                contactIds.add(contact.id);
            }
            // Assign the contacts to the class property contactrecordIds
            this.contactRecordIds = contactIds;
        }
    }
    
    // Helper class to handle date range operations
    public class DateRangeHelper {
        
        // Method to return the total number of days between date ranges
        public Integer getTotalDaysBetweenDateRanges(List<DateRange> dateRanges) {
            Set<Date> uniqueDates = new Set<Date>();
            for (DateRange range : dateRanges) {
                for (Date mdate = range.startDate; mdate<= range.endDate && mdate <= system.today(); mdate = mdate.addDays(1)) {
                    uniqueDates.add(mdate); 
                }
            }
            
            return uniqueDates.size();
        }
        
        // Method to return the total number of days between date ranges
        public Date getMinDate(List<DateRange> dateRanges) {
            Date minDate = null;
            for (DateRange range : dateRanges) {
                if(minDate!= null && minDate > range.startDate ){
                    minDate = range.startDate;
                }
                if(minDate == null) {
                    minDate = range.startDate;  
                }
            }
            return minDate;
        }
        
        // Get Max date for Membership Expiry
        public Date getMaxDate(List<DateRange> dateRanges) {
            Date maxDate = null;
            for (DateRange range : dateRanges) {
                if(maxDate!= null && maxDate < range.endDate ){
                    maxDate = range.endDate;
                }
                if(maxDate == null) {
                    maxDate = range.endDate;  
                }
            }
            return maxDate;
        }
    }
    
    // Inner class to represent a date range
    public class DateRange {
        public Date startDate;
        public Date endDate;
        
        public DateRange(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        String query = '';
        if(accountRecordIds.size() > 0){
            query = 'select id, Current_Join_Date__c, Membership_Expiry_Date__c, Days_Continuous_Membership__c from account where Id IN :accountRecordIds';
        }
        
        return Database.getQueryLocator(query);
    }
    
    // Schedule method
    global void execute(SchedulableContext ctx){
        KeepTrackingAccountMembershipBatchClass batch = new KeepTrackingAccountMembershipBatchClass();
        if(accountRecordIds.size() > 0){
            Database.executebatch(batch,50); 
            System.debug('Scheduled job executed at: batch executed ' + Datetime.now());
        } else {
            System.debug('Scheduled job executed at: ' + Datetime.now());
        }
    }    
    
    global void execute(Database.BatchableContext bc, List<Account> accounts) {
        
        // Create a map to store unique Contact records based on their Id
        Map<Id, Account> uniqueAccountsMap = new Map<Id, Account>();
        // Process each Account record
        for (Account account : accounts) {
            // Initialize Account record
            Account relatedAccount = new Account(Id = account.id);			             
            
            // For calculating active total membership days
            List<DateRange> memberActiveDateRanges = new List<DateRange>();
            
            // Process all the term records of contact
            Map<ID,DateRange> subscriptionStartEndDate = new Map<ID, DateRange>();
            List<OrderApi__Renewal__c> terms = [SELECT id, OrderApi__Subscription__c,OrderApi__Previous_Term__r.OrderApi__Term_End_Date__c, OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c FROM  OrderApi__Renewal__c where OrderApi__Account__c = :account.Id and  OrderApi__Entity__c = 'account' and OrderApi__Subscription__r.OrderApi__Status__c = 'Active'  order by OrderApi__Term_Start_Date__c asc];	
            for (OrderApi__Renewal__c termRecord : terms) {
                // active terms and future terms
                if(subscriptionStartEndDate.containsKey(termRecord.OrderApi__Subscription__c)){
                    DateRange DateRangevalue = subscriptionStartEndDate.get(termRecord.OrderApi__Subscription__c);
                    if(termRecord.OrderApi__Term_Start_Date__c == DateRangevalue.endDate.addDays(1) ){
                        subscriptionStartEndDate.put(termRecord.OrderApi__Subscription__c,new KeepTrackingAccountMembershipBatchClass.DateRange(DateRangevalue.startDate, termRecord.OrderApi__Term_End_Date__c));
                    } else {
                        subscriptionStartEndDate.put(termRecord.OrderApi__Subscription__c,new KeepTrackingAccountMembershipBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                    }
                } else {
                    subscriptionStartEndDate.put(termRecord.OrderApi__Subscription__c,new KeepTrackingAccountMembershipBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                }
            }
            
            // Populate all the terms of active subscription earliest Terms Start Date and latest Terms expiry date of all the active subscription
            for (ID subsID : subscriptionStartEndDate.keySet()) {
                DateRange DateRangevalue = subscriptionStartEndDate.get(subsID);
                memberActiveDateRanges.add(new KeepTrackingAccountMembershipBatchClass.DateRange(DateRangevalue.startDate, DateRangevalue.endDate));
            }
            
            // Initialize helper class
            DateRangeHelper helperDate = new DateRangeHelper();
            boolean updateFlag = False;
            // Update Account record when there is a active membership
            if(memberActiveDateRanges.size() == 0) {
                if(account.Current_Join_Date__c != null){
                    relatedAccount.Current_Join_Date__c = null;
                    relatedAccount.Days_Continuous_Membership__c = null; 
                    updateFlag = True;                     
                }
            } else {
                date minDate = helperDate.getMinDate(memberActiveDateRanges);
                if(account.Current_Join_Date__c != minDate){
                    relatedAccount.Current_Join_Date__c = minDate;
                    updateFlag = True; 
                }
                date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                if(account.Membership_Expiry_Date__c != maxDate){
                    relatedAccount.Membership_Expiry_Date__c = maxDate;
                    updateFlag = True; 
                }
            }
            
            if(updateFlag == True){
                uniqueAccountsMap.put(relatedAccount.id,relatedAccount);
            }
        }
        
        //Update DML statement
        if(uniqueAccountsMap.size() > 0){
            //Copy all values to Account list
            List<Account> accountsToUpdate = new List<Account>(uniqueAccountsMap.values());
            update accountsToUpdate;
        }
        //System.debug('Dumping Map Values: ' + String.join(new List<Contact>(contactMap.values()), ', '));
    }
    
    global void finish(Database.BatchableContext bc) {
        if(!Test.isRunningTest()){
            // Now the contactIds set contains all the contact IDs associated with the specified account
            KeepTrackingContactMembershipBatchClass SecondbatchJob = new KeepTrackingContactMembershipBatchClass(contactRecordIds);
            Id batchId =  Database.executeBatch(SecondbatchJob,50);
        }
    }
}