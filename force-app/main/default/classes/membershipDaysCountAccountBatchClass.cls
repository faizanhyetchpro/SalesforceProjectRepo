global class membershipDaysCountAccountBatchClass implements Database.Batchable<SObject> , Schedulable{

    // Instance variable to store the Set of IDs
    private Set<Id> accountRecordIds;
    // Constructor to initialize values
	 public membershipDaysCountAccountBatchClass() {
         
         Set<Id> accountIds = new Set<Id>();
         
         // To update Total continous days and Total Membership days
         for (OrderApi__Subscription__c subscription : [Select OrderApi__Account__c from OrderApi__Subscription__c  where OrderApi__Is_Active__c = true AND OrderApi__Entity__c = 'Account' And OrderApi__Activated_Date__c != null]){
             accountIds.add(subscription.OrderApi__Account__c);
         }
         
         if(accountIds.size() > 0){
             // Assign the accounts to the class property accountrecordIds
             this.accountRecordIds = accountIds;
         }
         
     }

    // Constructor with contact ids as parameter
    public membershipDaysCountAccountBatchClass(Set<Id> recordIds) {
        this.accountRecordIds = recordIds;
    }
    
    // Helper class to handle date range operations
    public class DateRangeHelper {
        // Method to return the total number of days between date ranges
        public Integer getTotalDaysBetweenDateRanges(List<DateRange> dateRanges) {
            Set<Date> uniqueDates = new Set<Date>();
            for (DateRange range : dateRanges) {
                System.debug('Start Date: ' + range.startDate + ', End Date: ' + range.endDate);
                for (Date mdate = range.startDate; mdate<= range.endDate && mdate <= system.today(); mdate = mdate.addDays(1)) {
                       uniqueDates.add(mdate); 
                }
            }
            return uniqueDates.size();
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
			query = 'select id, Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c from account  where Id IN :accountRecordIds';
        }	
        return Database.getQueryLocator(query);
    }

     global void execute(SchedulableContext ctx){
        membershipDaysCountAccountBatchClass batch = new membershipDaysCountAccountBatchClass();
        Database.executebatch(batch,50);
    }   
    
    global void execute(Database.BatchableContext bc, List<Account> accounts) {

         // Create a map to store unique Contact records based on their Id
		 Map<Id, Account> uniqueAccountsMap = new Map<Id, Account>();
         // Process each Contact record
         for (Account account : accounts) {
             // Initialize Contact record
			 Account relatedAccount = new Account(Id = account.id);			             

             // For calculating total membership days
             List<DateRange> allDateRanges = new List<DateRange>();
             
             // For calculating active total membership days
             List<DateRange> memberActiveDateRanges = new List<DateRange>();
             List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c FROM  OrderApi__Renewal__c where OrderApi__Account__c = :account.Id and  OrderApi__Entity__c = 'account' and OrderApi__Subscription__c != null and OrderApi__Term_Start_Date__c != null and OrderApi__Term_Start_Date__c <= TODAY and OrderApi__Term_End_Date__c != null  order by OrderApi__Term_Start_Date__c asc];	
             for (OrderApi__Renewal__c termRecord : terms) {
                 //list of date range for the total days
                 if(termRecord.OrderApi__Subscription__r.OrderApi__Is_Cancelled__c == True && termRecord.OrderApi__Term_End_Date__c >= termRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c && termRecord.OrderApi__Term_Start_Date__c <= termRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c){
                     allDateRanges.add(new membershipDaysCountAccountBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c));
                 } else {
                     allDateRanges.add(new membershipDaysCountAccountBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                 }
             }

             // Initialize helper class
             DateRangeHelper helperDate = new DateRangeHelper();
             boolean updateFlag = False;
             // Update Total Continous days
             if(account.Current_Join_Date__c != null) {
                 relatedAccount.Days_Continuous_Membership__c = account.Current_Join_Date__c.daysBetween(system.today() + 1);
                 updateFlag = True;
             } else{
                 if(account.Days_Continuous_Membership__c != 0 && account.Days_Continuous_Membership__c != null) {
                   relatedAccount.Days_Continuous_Membership__c = null;
                   updateFlag = True;
                 }
             }
             // Update total membership days
             if(allDateRanges.size() > 0){
               Integer totalDays = helperDate.getTotalDaysBetweenDateRanges(allDateRanges);
                 if(totalDays != account.Total_Days_Membership__c){
                     relatedAccount.Total_Days_Membership__c = totalDays;
                     updateFlag = True;
                 }
             }
             // Update Contact record when there is a active membership or assignments
             if(updateFlag == True){
             	uniqueAccountsMap.put(relatedAccount.id,relatedAccount);
             }
         }
		 
        //Update DML statement
         if(uniqueAccountsMap.size() > 0){
             List<Account> accountsToUpdate = new List<Account>(uniqueAccountsMap.values());
        	 update accountsToUpdate;
         }
    }
    
    global void finish(Database.BatchableContext bc) {
        // Max heap size
    }
}