global class membershipDaysCountContactBatchClass implements Database.Batchable<SObject> , Schedulable{

    // Instance variable to store the Set of IDs
    private Set<Id> contactRecordIds;
    // Constructor to initialize values
	 public membershipDaysCountContactBatchClass() {
         
         Set<Id> contactIds = new Set<Id>();
         
         // To update Total continous days and Total Membership days
         for (OrderApi__Subscription__c subscription : [Select OrderApi__Contact__c from OrderApi__Subscription__c  where OrderApi__Is_Active__c = true AND OrderApi__Entity__c = 'Contact' And OrderApi__Activated_Date__c != null]){
             contactIds.add(subscription.OrderApi__Contact__c);
         }
         
         // To update Total continous days and Total Membership days
         for(OrderApi__Assignment__c assignment : [Select OrderApi__Contact__c from OrderApi__Assignment__c where OrderApi__Is_Active__c = true AND OrderApi__Assigned_Date__c !=Null AND OrderApi__Subscription__c !=Null AND OrderApi__Term__c !=Null AND OrderApi__Term__r.OrderApi__Is_Active__c=true]){
             contactIds.add(assignment.OrderApi__Contact__c);
         }
         
         if(contactIds.size() > 0){
             // Assign the contacts to the class property contactrecordIds
             this.contactRecordIds = contactIds;
         }
         
     }

    // Constructor with contact ids as parameter
    public membershipDaysCountContactBatchClass(Set<Id> recordIds) {
        this.contactRecordIds = recordIds;
    }
    
    // Helper class to handle date range operations
    public class DateRangeHelper {
        // Method to return the total number of days between date ranges
        public Integer getTotalDaysBetweenDateRanges(List<DateRange> dateRanges) {
            Set<Date> uniqueDates = new Set<Date>();
            for (DateRange range : dateRanges) {
                // System.debug('Start Date: ' + range.startDate + ', End Date: ' + range.endDate);
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
        if(contactRecordIds.size() > 0){
			query = 'select id, Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c,(select OrderApi__Contact__c,OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c, OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c,OrderApi__Term__r.OrderApi__Is_Active__c,OrderApi__Term__r.OrderApi__Term_End_Date__c,OrderApi__Term__r.OrderApi__Term_Start_Date__c,OrderApi__Assigned_Date__c,OrderApi__Is_Unassigned__c,OrderApi__Unassigned_Date__c,OrderApi__Term__c,OrderApi__Subscription__c from OrderApi__Assignments__r where OrderApi__Assigned_Date__c != null and OrderApi__Assigned_Date__c <= TODAY and OrderApi__Subscription__c != null and OrderApi__Term__c != null order by OrderApi__Assigned_Date__c asc) from contact  where Id IN :contactRecordIds';
        }	
        return Database.getQueryLocator(query);
    }

    global void execute(SchedulableContext ctx){
        membershipDaysCountContactBatchClass batch = new membershipDaysCountContactBatchClass();
        Database.executebatch(batch,50);
    }
    
    global void execute(Database.BatchableContext bc, List<Contact> contacts) {

         // Create a map to store unique Contact records based on their Id
		 Map<Id, Contact> uniqueContactsMap = new Map<Id, Contact>();
         // Process each Contact record
         for (Contact contact : contacts) {
             // Initialize Contact record
			 Contact relatedContact = new Contact(Id = contact.id);			             

             // For calculating total membership days
             List<DateRange> allDateRanges = new List<DateRange>();
             
             // For calculating active total membership days
             List<DateRange> memberActiveDateRanges = new List<DateRange>();
             List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c = :contact.Id and  OrderApi__Entity__c = 'contact' and OrderApi__Subscription__c != null and OrderApi__Term_Start_Date__c != null and OrderApi__Term_Start_Date__c <= TODAY and OrderApi__Term_End_Date__c != null  order by OrderApi__Term_Start_Date__c asc];	
             for (OrderApi__Renewal__c termRecord : terms) {
                 //list of date range for the total days
                 if(termRecord.OrderApi__Subscription__r.OrderApi__Is_Cancelled__c == True && termRecord.OrderApi__Term_End_Date__c >= termRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c && termRecord.OrderApi__Term_Start_Date__c <= termRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c){
                     allDateRanges.add(new membershipDaysCountContactBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c));
                 } else {
                     allDateRanges.add(new membershipDaysCountContactBatchClass.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                 }
             }

             // Process all the term records of contact
             List<OrderApi__Assignment__c> assignments = contact.OrderApi__Assignments__r;

             // Process all the assignments of contact
			 for (OrderApi__Assignment__c assignmentRecord : assignments) {
                 // when assignment is unassigned
                 If(assignmentRecord.OrderApi__Is_Unassigned__c == True && assignmentRecord.OrderApi__Unassigned_Date__c <= system.today()){
					 allDateRanges.add(new membershipDaysCountContactBatchClass.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Unassigned_Date__c));                    
                 } else if (assignmentRecord.OrderApi__Is_Active__c == True && assignmentRecord.OrderApi__Term__r.OrderApi__Is_Active__c == True) {
                     // When Assignment is active and Term is active
                     allDateRanges.add(new membershipDaysCountContactBatchClass.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Term__r.OrderApi__Term_End_Date__c));
                 } else if(assignmentRecord.OrderApi__Is_Active__c == False && assignmentRecord.OrderApi__Term__r.OrderApi__Is_Active__c == False && assignmentRecord.OrderApi__Subscription__r.OrderApi__Status__c == 'Expired') {
                     // When Assignment is inactive and term is inactive and subcription expired
                     allDateRanges.add(new membershipDaysCountContactBatchClass.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Term__r.OrderApi__Term_End_Date__c));
                 }  else if(assignmentRecord.OrderApi__Is_Active__c == False && assignmentRecord.OrderApi__Term__r.OrderApi__Is_Active__c == False && assignmentRecord.OrderApi__Subscription__r.OrderApi__Is_Cancelled__c && assignmentRecord.OrderApi__Subscription__r.OrderApi__Status__c == 'Cancelled') {
                     // When Assignment is inactive and term is inactive and subcription cancelled
                     allDateRanges.add(new membershipDaysCountContactBatchClass.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Subscription__r.OrderApi__Cancelled_Date__c));
                 }
             }	
             // Initialize helper class
             DateRangeHelper helperDate = new DateRangeHelper();
             boolean updateFlag = False;
             // Update Total Continous days
             if(contact.Current_Join_Date__c != null) {
                 relatedContact.Days_Continuous_Membership__c = contact.Current_Join_Date__c.daysBetween(system.today() + 1);
                 updateFlag = True;
             } else{
                 if(contact.Days_Continuous_Membership__c != 0 && contact.Days_Continuous_Membership__c != null) {
                   relatedContact.Days_Continuous_Membership__c = null;
                   updateFlag = True;
                 }
             }
             // Update total membership days
             if(allDateRanges.size() > 0){
               Integer totalDays = helperDate.getTotalDaysBetweenDateRanges(allDateRanges);
                 if(totalDays != contact.Total_Days_Membership__c){
                     relatedContact.Total_Days_Membership__c = totalDays;
                     updateFlag = True;
                 }
             }
             // Update Contact record when there is a active membership or assignments
             if(updateFlag == True){
             	uniqueContactsMap.put(relatedContact.id,relatedContact);
             }
         }
		 
        //Update DML statement
         if(uniqueContactsMap.size() > 0){
             List<Contact> contactsToUpdate = new List<Contact>(uniqueContactsMap.values());
        	 update contactsToUpdate;
         }
    }
    
    global void finish(Database.BatchableContext bc) {
        // Max heap size
    }
}