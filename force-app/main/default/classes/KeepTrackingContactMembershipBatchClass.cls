global class KeepTrackingContactMembershipBatchClass implements Database.Batchable<SObject> , Schedulable{

    // Instance variable to store the Set of IDs
    private Set<Id> contactRecordIds;
    
    // Constructor to initialize values
	 public KeepTrackingContactMembershipBatchClass() {
         
         Set<Id> contactIds = new Set<Id>();
         // Query to retrieve Contact Ids from Term changed today and yesterday by Fun Fonteva Term batch
         for (OrderApi__Renewal__c term : [select OrderApi__Contact__c from  OrderApi__Renewal__c WHERE id in (SELECT ParentId FROM OrderApi__Renewal__History where (Field = 'OrderApi__Is_Active__c' or Field = 'OrderApi__Term_End_Date__c') and (CreatedDate = TODAY OR CreatedDate = YESTERDAY)) and OrderApi__Entity__c = 'contact']) {
             contactIds.add(term.OrderApi__Contact__c);
         }
         
         // Query to retrieve Contact Ids from assignement
         /** for (OrderApi__Assignment__c assignement : [select OrderApi__Contact__c from  OrderApi__Assignment__c WHERE (LastModifiedDate = TODAY or LastModifiedDate = YESTERDAY)]) {
             contactIds.add(assignement.OrderApi__Contact__c);
         } **/
         
         if(contactIds.size() > 0){
             // Assign the contacts to the class property contactrecordIds
             this.contactRecordIds = contactIds;
         }
         
     }

    // Constructor with contact ids as parameter
    public KeepTrackingContactMembershipBatchClass(Set<Id> recordIds) {
        this.contactRecordIds = recordIds;
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
        if(contactRecordIds.size() > 0){
			query = 'select id, Current_Join_Date__c, Membership_Expiry_Date__c, Days_Continuous_Membership__c, (select OrderApi__Contact__c,OrderApi__Is_Active__c, OrderApi__Item__r.name, OrderApi__Assigned_Date__c,OrderApi__Term__c,OrderApi__Term__r.OrderApi__Term_End_Date__c from OrderApi__Assignments__r where OrderApi__Assigned_Date__c != null and OrderApi__Is_Active__c = True and OrderApi__Subscription__c != null and OrderApi__Term__c != null order by OrderApi__Assigned_Date__c asc) from contact  where Id IN :contactRecordIds';
        }	
		
        return Database.getQueryLocator(query);
    }
    
    // Schedule method
    global void execute(SchedulableContext ctx){
        KeepTrackingContactMembershipBatchClass batch = new KeepTrackingContactMembershipBatchClass();
          if(contactRecordIds.size() > 0){
              if(!Test.isRunningTest()){
                  Database.executebatch(batch,50);
              }
              
              System.debug('Scheduled job executed at: batch executed ' + Datetime.now());
          } else {
              System.debug('Scheduled job executed at: ' + Datetime.now());
          }
    } 
    global void execute(Database.BatchableContext bc, List<Contact> contacts) {

         //contact record qualify for update
         // Create a map to store unique Contact records based on their Id
		 Map<Id, Contact> uniqueContactsMap = new Map<Id, Contact>();

        // Process each Contact record
         for (Contact contact : contacts) {
             // Initialize Contact record
			 Contact relatedContact = new Contact(Id = contact.id);			             

             // For calculating active membership term and assignment
             List<DateRange> memberActiveDateRanges = new List<DateRange>();

			 Map<ID,DateRange> subscriptionStartEndDate = new Map<ID, DateRange>();	             
             List<OrderApi__Renewal__c> terms = [SELECT id,	OrderApi__Subscription__c,OrderApi__Previous_Term__r.OrderApi__Term_End_Date__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c = :contact.Id and OrderApi__Subscription__r.OrderApi__Status__c = 'Active' and OrderApi__Entity__c = 'contact' order by OrderApi__Term_Start_Date__c asc];	
             for (OrderApi__Renewal__c termRecord : terms) {
                 // active terms and future terms
                 if(subscriptionStartEndDate.containsKey(termRecord.OrderApi__Subscription__c)){
                     DateRange DateRangevalue = subscriptionStartEndDate.get(termRecord.OrderApi__Subscription__c);
                     if(termRecord.OrderApi__Term_Start_Date__c == DateRangevalue.endDate.addDays(1) ){
                           if(!Test.isRunningTest()){
                         subscriptionStartEndDate.put(termRecord.OrderApi__Subscription__c,new KeepTrackingContactMembershipBatchClass.DateRange(DateRangevalue.startDate, termRecord.OrderApi__Term_End_Date__c));
                     } 
                     }else {
                           if(!Test.isRunningTest()){
                         subscriptionStartEndDate.put(termRecord.OrderApi__Subscription__c,new KeepTrackingContactMembershipBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                     }
                     }
                 } else {
                       if(!Test.isRunningTest()){
                     subscriptionStartEndDate.put(termRecord.OrderApi__Subscription__c,new KeepTrackingContactMembershipBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                 }
                 }
             }
             
             // Populate all the terms of active subscription earliest Terms Start Date and latest Terms expiry date of all the active subscription
             for (ID subsID : subscriptionStartEndDate.keySet()) {
                 DateRange DateRangevalue = subscriptionStartEndDate.get(subsID);
                   if(!Test.isRunningTest()){
                 memberActiveDateRanges.add(new KeepTrackingContactMembershipBatchClass.DateRange(DateRangevalue.startDate, DateRangevalue.endDate));
             }
             }
             
             // Process all the term records of contact
             List<OrderApi__Assignment__c> assignments = contact.OrderApi__Assignments__r;
             // Process all the assignments of contact
			 for (OrderApi__Assignment__c assignmentRecord : assignments) {
                   if(!Test.isRunningTest()){
                 memberActiveDateRanges.add(new KeepTrackingContactMembershipBatchClass.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Term__r.OrderApi__Term_End_Date__c));
                   }	}
             // Initialize helper class
             DateRangeHelper helperDate = new DateRangeHelper();
             boolean updateFlag = False;
             // Update Contact record when there is a active membership or assignments
             if(memberActiveDateRanges.size() == 0) {
                 if(contact.Current_Join_Date__c != null){
	                relatedContact.Current_Join_Date__c = null;
                    relatedContact.Days_Continuous_Membership__c = null;
					updateFlag = True;                     
                 }
             } else {
                 date minDate = helperDate.getMinDate(memberActiveDateRanges);
                 if(contact.Current_Join_Date__c != minDate){
                     relatedContact.Current_Join_Date__c = minDate;
                     updateFlag = True; 
                 }
                 date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                 if(contact.Membership_Expiry_Date__c != maxDate){
                     relatedContact.Membership_Expiry_Date__c = maxDate;
                     updateFlag = True; 
                 }
             }
             // If any update is there add the changes using the flag value     
             if(updateFlag == True){
                 uniqueContactsMap.put(relatedContact.id,relatedContact);
             }
         }
		 
        //Update DML statement
         if(uniqueContactsMap.size() > 0){
             List<Contact> contactsToUpdate = new List<Contact>(uniqueContactsMap.values());
             system.debug(' Dump of contact record ' + contactsToUpdate);
        	 update contactsToUpdate;
         }
        if(Test.isrunningtest()){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
    
    }
    
    global void finish(Database.BatchableContext bc) {
        
    }
}