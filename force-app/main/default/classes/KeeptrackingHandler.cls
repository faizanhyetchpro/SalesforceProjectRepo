public class KeeptrackingHandler {
    
	// Query Account and return contact id's in a list 
    public static List<Contact> getContactsByAccount(OrderApi__Renewal__c termrec) {
        // Query contacts related to the specified account
        return [SELECT Id FROM Contact WHERE AccountId = :termrec.OrderApi__Account__c and id in (select OrderApi__Contact__c from OrderApi__Assignment__c where OrderApi__Term__c = :termrec.id and OrderApi__Is_Unassigned__c = False)];
    }
    
    // Query Contact and return contact record
    public static Contact getContact(Id contactId) {
        // Query contacts related to the specified account
        return [SELECT Id FROM Contact WHERE id = :contactId limit 1];
    }
    
    // Query Term and return Term record 
    public static OrderApi__Renewal__c geTerm(Id termId) {
        // Query contacts related to the specified account
        return [SELECT Id FROM OrderApi__Renewal__c WHERE id = :termId limit 1];
    }
    
    public static String getItemNameByTerm(Id termId) {
        // Query contacts related to the specified account
        List<OrderApi__Item__c> items = [SELECT Name FROM OrderApi__Item__c WHERE Id = :termId limit 1];
        for (OrderApi__Item__c item : items) {
            // Access fields of each contact
            return(item.Name);
        }
        return null;
    }
    // Subscription reinstated
    public static boolean reinstate(OrderApi__Renewal__c termrec) {
        boolean match = false;
        // Query contacts related to the specified account
        List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Previous_Term__r.OrderApi__Term_End_Date__c,OrderApi__Term_Start_Date__c FROM OrderApi__Renewal__c WHERE Id = :termrec.id limit 1];
        for (OrderApi__Renewal__c term : terms) {
            // Access fields of each contact
            if(term.OrderApi__Previous_Term__r.OrderApi__Term_End_Date__c != null){
                date previousDate = term.OrderApi__Previous_Term__r.OrderApi__Term_End_Date__c;
                if(  previousDate.addDays(1) != term.OrderApi__Term_Start_Date__c){
                    match = True;
                }
            }
        }
        return match;
    }
    
    // Return cancelled date of term
    public static Date getCancellationDateByTerm(Id subscriptionId) {
        // Query contacts related to the specified account
        List<OrderApi__Subscription__c> subscriptions = [SELECT OrderApi__Cancelled_Date__c FROM OrderApi__Subscription__c WHERE Id = :subscriptionId and OrderApi__Status__c = 'Cancelled' limit 1];
        for (OrderApi__Subscription__c subscription : subscriptions) {
            // Access fields of each contact
            return(subscription.OrderApi__Cancelled_Date__c);
        }
        return null;
    }
    
    // Return subscription expired date when term expries
    public static Date getExpiredDateByTerm(Id subscriptionId) {
        // Query contacts related to the specified account
        List<OrderApi__Subscription__c> subscriptions = [SELECT OrderApi__Expired_Date__c FROM OrderApi__Subscription__c WHERE Id = :subscriptionId and OrderApi__Status__c = 'Expired' limit 1];
        for (OrderApi__Subscription__c subscription : subscriptions) {
            // Access fields of each contact
            return(subscription.OrderApi__Expired_Date__c);
        }
        return null;
    }
    
    // Return subscription paid through date when term expries
    public static Date getSubscriptionPaidThroughDateByTerm(Id subscriptionId) {
        // Query contacts related to the specified account
        List<OrderApi__Subscription__c> subscriptions = [SELECT OrderApi__Paid_Through_Date__c FROM OrderApi__Subscription__c WHERE Id = :subscriptionId and OrderApi__Status__c = 'Expired' limit 1];
        for (OrderApi__Subscription__c subscription : subscriptions) {
            // Access fields of each contact
            return(subscription.OrderApi__Paid_Through_Date__c);
        }
        return null;
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
	
    public class collectionJoinDateMembershipType {
        public Date joinDate;
        public String membershipItem;
        
        public collectionJoinDateMembershipType(Date joinDate, String membershipItem) {
            this.joinDate = joinDate;
            this.membershipItem = membershipItem;
        }
    }
    
    public static collectionJoinDateMembershipType compare(Contact contact, List<OrderApi__Assignment__c> assignments){
        // Update the Initial Join Date if it's null or Initital Membership type.
        List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Item__r.name,OrderApi__Subscription__r.OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Sales_Order_Line__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c,OrderApi__Sales_Order_Line__r.OrderApi__Is_Renewal__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c = :contact.Id and  OrderApi__Entity__c = 'contact' order by OrderApi__Term_Start_Date__c asc];	
        
        // When subscription and assignment both are not empty
        if (terms.size() > 0 && !assignments.isEmpty()) {
            // When subscription first activation date is less than or equal to first Assignment date assign subscription date to Initial Join date
            if(terms[0].OrderApi__Term_Start_Date__c <= assignments[0].OrderApi__Assigned_Date__c){
                return new collectionJoinDateMembershipType(terms[0].OrderApi__Term_Start_Date__c, terms[0].OrderApi__Item__r.name);
            } else {
                // When first assignment date is less than first subscription date assign assignment date to Initial join date
                return new collectionJoinDateMembershipType(assignments[0].OrderApi__Assigned_Date__c, assignments[0].OrderApi__Item__r.name);
            }
        } 
        // only subscription is there no assignment
        else if (terms.size() > 0 && assignments.isEmpty()) {
            return new collectionJoinDateMembershipType(terms[0].OrderApi__Term_Start_Date__c, terms[0].OrderApi__Item__r.name);
        } 
        // Only Assignment is there no Subscription
        else if (!(terms.size() > 0) && !assignments.isEmpty()){
            return new collectionJoinDateMembershipType(assignments[0].OrderApi__Assigned_Date__c, assignments[0].OrderApi__Item__r.name);
            
        }
        // End of Initial join date calculation

        return new collectionJoinDateMembershipType(null, null);
    }
    public static collectionJoinDateMembershipType assignmentCompare(OrderApi__Renewal__c term, List<OrderApi__Assignment__c> assignments){
        // Update the Initial Join Date if it's null or Initital Membership type.
       // List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Item__r.name,OrderApi__Subscription__r.OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Sales_Order_Line__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c,OrderApi__Sales_Order_Line__r.OrderApi__Is_Renewal__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c = :contact.Id and  OrderApi__Entity__c = 'contact' order by OrderApi__Term_Start_Date__c asc];	
        
        // When subscription and assignment both are not empty
        if (term != null && !assignments.isEmpty()) {
            // When subscription first activation date is less than or equal to first Assignment date assign subscription date to Initial Join date
            if(term.OrderApi__Term_Start_Date__c <= assignments[0].OrderApi__Assigned_Date__c){
                return new collectionJoinDateMembershipType(term.OrderApi__Term_Start_Date__c, term.OrderApi__Item__r.name);
            } else {
                // When first assignment date is less than first subscription date assign assignment date to Initial join date
                return new collectionJoinDateMembershipType(assignments[0].OrderApi__Assigned_Date__c, assignments[0].OrderApi__Item__r.name);
            }
        } 
        // only subscription is there no assignment
        else if (term != null  && assignments.isEmpty()) {
            return new collectionJoinDateMembershipType(term.OrderApi__Term_Start_Date__c, term.OrderApi__Item__r.name);
        } 
        // Only Assignment is there no Subscription
        else if (!(term != null ) && !assignments.isEmpty()){
            return new collectionJoinDateMembershipType(assignments[0].OrderApi__Assigned_Date__c, assignments[0].OrderApi__Item__r.name);
            
        }
        // End of Initial join date calculation

        return new collectionJoinDateMembershipType(null, null);
    }
        
    public static void onInsertAssignment(List<OrderApi__Assignment__c> lstAssignments){
        if(lstAssignments.size() == 1){
            for(OrderApi__Assignment__c obj : lstAssignments) {
                if(obj.OrderApi__Is_Active__c && obj.OrderApi__Subscription__c != null && obj.OrderApi__Contact__c !=null && obj.OrderApi__Assigned_Date__c <= System.today() && obj.OrderApi__Term__c != Null) {
                    Contact conRec = KeeptrackingHandler.getContact(obj.OrderApi__Contact__c);
                    OrderApi__Renewal__c  termRec = KeeptrackingHandler.geTerm(obj.OrderApi__Term__c);
                    KeeptrackingHandler.updateContactAssignment(conRec,termRec, 1);
                }
            }		                
        }
    }

    public static void onInsertTerm(List<OrderApi__Renewal__c> lstTerms){
    Set<Id> contactIds = new Set<Id>();
    Set<Id> accountIds = new Set<Id>();
    Map<Id, Date> contactExpiryDates = new Map<Id, Date>();
    Map<Id, Date> accountExpiryDates = new Map<Id, Date>();
       try {
             if(lstTerms[0].OrderApi__Subscription__r.OrderApi__Status__c == 'Pending'){
               if(lstTerms[0].OrderApi__Subscription__r.OrderApi__Entity__c == 'Account'){
                    accountIds.add(lstTerms[0].OrderApi__Subscription__r.OrderApi__Account__c);
                accountExpiryDates.put(lstTerms[0].OrderApi__Subscription__r.OrderApi__Account__c, lstTerms[0].OrderApi__Term_End_Date__c);
                   System.debug('Accountids--?'+accountIds);
               }
               else if(lstTerms[0].OrderApi__Subscription__r.OrderApi__Entity__c == 'Contact'){
                       contactIds.add(lstTerms[0].OrderApi__Subscription__r.OrderApi__Contact__c);
                contactExpiryDates.put(lstTerms[0].OrderApi__Subscription__r.OrderApi__Contact__c, lstTerms[0].OrderApi__Term_End_Date__c);
              System.debug('contactIds--?'+contactIds);
               }
           }
            // Update Contacts' Membership_Expiry_Date__c
    if(!contactIds.isEmpty()) {
        List<Contact> contactsToUpdate = new List<Contact>();
        for(Contact contact : [SELECT Id,no_of_Renewals__c, Membership_Expiry_Date__c FROM Contact WHERE Id IN :contactIds]) {
            if(contactExpiryDates.containsKey(contact.Id)) {
                   if (contact.no_of_Renewals__c == null) {
            contact.no_of_Renewals__c = 0;
        }
        // Increment the number of renewals
        contact.no_of_Renewals__c += 1;
        
                contact.Membership_Expiry_Date__c = contactExpiryDates.get(contact.Id);
                //contact.no_of_Renewals__c=contact.no_of_Renewals__c+1;
                contactsToUpdate.add(contact);
            }
        }
        if(!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
          System.debug('contactsToUpdate---------------->'+contactsToUpdate);
    }
    // Update Accounts' Membership_Expiry_Date__c
    if(!accountIds.isEmpty()) {
        List<Account> accountsToUpdate = new List<Account>();
        for(Account account : [SELECT Id, no_of_Renewals__c,Membership_Expiry_Date__c FROM Account WHERE Id IN :accountIds]) {
            if(accountExpiryDates.containsKey(account.Id)) {
                  if (account.no_of_Renewals__c == null) {
            account.no_of_Renewals__c = 0;
        }
        // Increment the number of renewals
        account.no_of_Renewals__c += 1;
        
                account.Membership_Expiry_Date__c = accountExpiryDates.get(account.Id);
                accountsToUpdate.add(account);
            }
              System.debug('accountsToUpdate---------------->'+accountsToUpdate);
        }
      
   
        if(!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
            // Individual membership purchased   
            if(lstTerms.size() == 1) {
                   if(lstTerms[0].OrderApi__Subscription__c != null && lstTerms[0].OrderApi__Is_Active__c && lstTerms[0].OrderApi__Previous_Term__c == null) {
                       KeeptrackingHandler.updateContact(lstTerms[0], 1);
                   } else if(lstTerms[0].OrderApi__Subscription__c != null && lstTerms[0].OrderApi__Previous_Term__c != null){
                       KeeptrackingHandler.updateContact(lstTerms[0], 2);
                   }
               }
           	// Program membership purchased
           if( lstTerms.size() == 1) {
               		system.debug('oninsertterm');
                   if(lstTerms[0].OrderApi__Subscription__c != null && lstTerms[0].OrderApi__Is_Active__c && lstTerms[0].OrderApi__Previous_Term__c == null) {
                       // Update the Account Fields
                       KeeptrackingHandler.updateAccount(lstTerms[0], 5);
                       // Update Contact as per the changes in assignment
                       List<Contact> accountContacts = KeeptrackingHandler.getContactsByAccount(lstTerms[0]);
                       KeeptrackingHandler.updateAccountAssignments(accountContacts, lstTerms[0], 1);
                   } else if(lstTerms[0].OrderApi__Subscription__c != null && lstTerms[0].OrderApi__Previous_Term__c != null){
                       KeeptrackingHandler.updateAccount(lstTerms[0], 6);
                       List<Contact> accountContacts = KeeptrackingHandler.getContactsByAccount(lstTerms[0]);
                       KeeptrackingHandler.updateAccountAssignments(accountContacts, lstTerms[0], 2);
                   }
           }
         
           
        } catch(Exception e) {
            System.debug('Exception--- '+e.getMessage()+' stacktrace--- '+e.getStackTraceString()+ ' Line Number ==' + e.getLineNumber());
        }
    }

    public static void onUpdateTerm(Map<Id, OrderApi__Renewal__c> newTerms, Map<Id, OrderApi__Renewal__c> oldTerms) {
        try {
            if( newTerms.size() == 1) {
                for(OrderApi__Renewal__c obj : newTerms.values()) {
                    // Cancellation for Individual Membership
                    if(obj.OrderApi__Is_Active__c != oldTerms.get(obj.Id).OrderApi__Is_Active__c && obj.OrderApi__Entity__c == 'Contact') {
                        // Subscription cancelled
                        if(obj.OrderApi__Subscription__c != null && obj.OrderApi__Is_Active__c == False) {
                            List<OrderApi__Subscription__c> subscriptionList = [SELECT Id,OrderApi__Is_Cancelled__c,OrderApi__Status__c FROM OrderApi__Subscription__c where id = :obj.OrderApi__Subscription__c and OrderApi__Entity__c = 'contact' and OrderApi__Is_Cancelled__c = True and OrderApi__Status__c = 'Cancelled'];
                            if(subscriptionList.size() > 0){
                                 KeeptrackingHandler.updateContact(obj, 3);
                            }	
                        }
                        // Subscription expired
                        if(obj.OrderApi__Subscription__c != null && obj.OrderApi__Is_Active__c == False) {
                            List<OrderApi__Subscription__c> subscriptionList = [SELECT Id,OrderApi__Expired_Date__c,OrderApi__Status__c FROM OrderApi__Subscription__c where id = :obj.OrderApi__Subscription__c and OrderApi__Entity__c = 'contact' and OrderApi__Status__c = 'Expired'];
                            if(subscriptionList.size() > 0){
                                KeeptrackingHandler.updateContact(obj, 4);
                            }
                        }
                    }
					// Cancellation for Program Membership
                    if(obj.OrderApi__Is_Active__c != oldTerms.get(obj.Id).OrderApi__Is_Active__c && obj.OrderApi__Entity__c == 'Account') {
                        system.debug('onupdateterm');
                        // Subscription cancelled
                        if(obj.OrderApi__Subscription__c != null && obj.OrderApi__Is_Active__c == False) {
                            List<OrderApi__Subscription__c> subscriptionList = [SELECT Id,OrderApi__Is_Cancelled__c,OrderApi__Status__c FROM OrderApi__Subscription__c where id = :obj.OrderApi__Subscription__c and OrderApi__Entity__c = 'account' and OrderApi__Is_Cancelled__c = True and OrderApi__Status__c = 'Cancelled'];
                            if(subscriptionList.size() > 0){
                                KeeptrackingHandler.updateAccount(obj, 7);
                                // Update Contact as per the changes in assignment
                                List<Contact> accountContacts = KeeptrackingHandler.getContactsByAccount(obj);
                                KeeptrackingHandler.updateAccountAssignments(accountContacts, obj, 3);
                            }
                        }
                        // Subscription expired
                        if(obj.OrderApi__Subscription__c != null && obj.OrderApi__Is_Active__c == False) {
                            List<OrderApi__Subscription__c> subscriptionList = [SELECT Id,OrderApi__Expired_Date__c,OrderApi__Status__c FROM OrderApi__Subscription__c where id = :obj.OrderApi__Subscription__c and OrderApi__Entity__c = 'account' and OrderApi__Status__c = 'Expired'];
                            if(subscriptionList.size() > 0) {
                                KeeptrackingHandler.updateAccount(obj, 8);
                                // Update Contact as per the changes in assignment
                                List<Contact> accountContacts = KeeptrackingHandler.getContactsByAccount(obj);
                                KeeptrackingHandler.updateAccountAssignments(accountContacts, obj, 4);
                            }
                        }
                    }
                }
            }
        } catch(Exception e) {
            System.debug('Exception--- '+e.getMessage()+' stacktrace--- '+e.getStackTraceString()+ ' Line Number ==' + e.getLineNumber());
        }
    }
    
    
    // Return active date range of contact from assignment and term objects
    public static List<DateRange> contactActiveDateRange(Contact contact, List<OrderApi__Assignment__c> Assignments){
        
        List<DateRange> memberActiveDateRanges = new List<DateRange>();
        
        List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Item__r.name,OrderApi__Subscription__r.OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Sales_Order_Line__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c,OrderApi__Sales_Order_Line__r.OrderApi__Is_Renewal__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c = :contact.Id and  OrderApi__Entity__c = 'contact' order by OrderApi__Term_Start_Date__c asc];	
        
        // Loop through all the Terms of a Contact	
        for (OrderApi__Renewal__c termRecord : terms) {
            // Push all the active Terms in a date range collection to retrive the Earliest Date
            if(termRecord.OrderApi__Subscription__r.OrderApi__Is_Active__c == True && termRecord.OrderApi__Is_Active__c == True){
                memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
            }
        }
        
        // Process all the assignments of contact
        for (OrderApi__Assignment__c assignmentRecord : Assignments) {
            // Push all active assignments
            if(assignmentRecord.OrderApi__Is_Active__c == True){
                // set the active date range of contact for terms
                memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Term__r.OrderApi__Term_End_Date__c));
            }
        }
        
        return memberActiveDateRanges;
    }

    public static List<DateRange> assignmentActiveDateRange(List<OrderApi__Renewal__c> terms, List<OrderApi__Assignment__c> Assignments){
        
        List<DateRange> memberActiveDateRanges = new List<DateRange>();
        
       // List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Item__r.name,OrderApi__Subscription__r.OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Sales_Order_Line__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c,OrderApi__Sales_Order_Line__r.OrderApi__Is_Renewal__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c = :contact.Id and  OrderApi__Entity__c = 'contact' order by OrderApi__Term_Start_Date__c asc];	
        
        // Loop through all the Terms of a Contact
        if(terms != null && terms.size() > 0){	
            for (OrderApi__Renewal__c termRecord : terms) {
                // Push all the active Terms in a date range collection to retrive the Earliest Date
                if(termRecord.OrderApi__Subscription__r.OrderApi__Is_Active__c == True && termRecord.OrderApi__Is_Active__c == True){
                    memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                }
            }
        }    
        
        // Process all the assignments of contact
        if(Assignments != null && Assignments.size() > 0){
            for (OrderApi__Assignment__c assignmentRecord : Assignments) {
                // Push all active assignments
                if(assignmentRecord.OrderApi__Is_Active__c == True){
                    // set the active date range of contact for terms
                    memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(assignmentRecord.OrderApi__Assigned_Date__c, assignmentRecord.OrderApi__Term__r.OrderApi__Term_End_Date__c));
                }
            }
        }
        
        return memberActiveDateRanges;
    }
    
    public static void updateAccountAssignments(List<Contact> con, OrderApi__Renewal__c termrec, integer optcode) {
        
        // Create a map to store unique Contact records based on their Id
        Map<Id, Contact> uniqueContactsMap = new Map<Id, Contact>();
        Set<ID> conidS = new Set<ID>();
        for(contact contactid : con) {
            conids.add(contactid.id);
        }
        
        if(con.size() > 0) {
            List<Contact> contacts = [select id, Initial_Join_Date__c,Initial_Membership_Type__c,Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c,no_of_Renewals__c,(select OrderApi__Contact__c,OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c, OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c,OrderApi__Term__r.OrderApi__Is_Active__c,OrderApi__Term__r.OrderApi__Term_End_Date__c,OrderApi__Term__r.OrderApi__Term_Start_Date__c,OrderApi__Item__r.name,OrderApi__Assigned_Date__c,OrderApi__Is_Unassigned__c,OrderApi__Unassigned_Date__c,OrderApi__Term__c from OrderApi__Assignments__r where OrderApi__Assigned_Date__c != null and OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c != null order by OrderApi__Assigned_Date__c asc) from contact where Id IN :conids];	
            Date subscriptionPaidThroughDate = KeeptrackingHandler.getSubscriptionPaidThroughDateByTerm(termrec.OrderApi__Subscription__c);
            Date cancellationDate = KeeptrackingHandler.getCancellationDateByTerm(termrec.OrderApi__Subscription__c);
            Map<Id, List<OrderApi__Renewal__c>> assignmentContactMap = new Map<Id, List<OrderApi__Renewal__c>>();
            Map<Id, OrderApi__Renewal__c> assignmentContactInitialJoinDateMap = new Map<Id, OrderApi__Renewal__c>();
            List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Contact__c,OrderApi__Item__r.name,OrderApi__Subscription__r.OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Sales_Order_Line__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c,OrderApi__Sales_Order_Line__r.OrderApi__Is_Renewal__c FROM  OrderApi__Renewal__c where OrderApi__Contact__c IN :conids and  OrderApi__Entity__c = 'contact' order by OrderApi__Term_Start_Date__c asc];	
            // Loop through the queried Terms and initialize the map
            for (OrderApi__Renewal__c term : terms) {
                
                // Get all the terms of a contact in a map
                 if (!assignmentContactMap.containsKey(term.OrderApi__Contact__c)) {
                    assignmentContactMap.put(term.OrderApi__Contact__c, new List<OrderApi__Renewal__c>());
                }
                assignmentContactMap.get(term.OrderApi__Contact__c).add(term);
                
                // Get the initial term for each contact in a map
                if (!assignmentContactInitialJoinDateMap.containsKey(term.OrderApi__Contact__c)) {
                    //assignmentContactInitialJoinDateMap.put(term.OrderApi__Contact__c, new OrderApi__Renewal__c());
                    assignmentContactInitialJoinDateMap.put(term.OrderApi__Contact__c, term);  
                } else {
                     OrderApi__Renewal__c existingTerm = assignmentContactInitialJoinDateMap.get(term.OrderApi__Contact__c);
                        if(existingTerm.OrderApi__Term_Start_Date__c < term.OrderApi__Term_Start_Date__c){
                            assignmentContactInitialJoinDateMap.put(term.OrderApi__Contact__c, term);                    
                        }
                }
            }
            
            // Dumping the contents of the map
            System.debug(' assignmentContactInitialJoinDateMap ' + assignmentContactInitialJoinDateMap.values());
            System.debug(' assignmentContactMap ' + assignmentContactMap.values());
            
            // Calculate Membership tracking field values for a Contact
            for (Contact contact : contacts) {
                // Initialize Contact record
                Contact relatedContact = new Contact(Id = contact.id);			             
                // For calculating total membership days
                List<DateRange> allDateRanges = new List<DateRange>();
                
                // For calculating active membership term and assignment
                List<DateRange> memberActiveDateRanges = new List<DateRange>();
				memberActiveDateRanges = KeeptrackingHandler.assignmentActiveDateRange(assignmentContactMap.get(contact.id),contact.OrderApi__Assignments__r);
                System.debug(' memberActiveDateRanges ' + memberActiveDateRanges);
                // Initialize helper class
                DateRangeHelper helperDate = new DateRangeHelper();
                boolean UpdateFlag = False;
                // Update Contact record when there is a active membership or assignments
                System.debug(' assignment__r ' + contact.OrderApi__Assignments__r);
                if(optcode == 1) {
                    // Individual Membership Purchase
                    if(memberActiveDateRanges.size() > 0) {
                        if(contact.Initial_Join_Date__c == null){
                            // compare first row terms and assignment to get value for initialize current join date and initial Membership type
                            collectionJoinDateMembershipType cmp = KeeptrackingHandler.assignmentCompare(assignmentContactInitialJoinDateMap.get(contact.id),contact.OrderApi__Assignments__r);
                            relatedContact.Initial_Join_Date__c = cmp.joinDate;
                            relatedContact.Initial_Membership_Type__c = cmp.membershipItem;
                            //Add in the update contact list
                            UpdateFlag = True;
                            System.debug(' cmp ' + cmp);
                        }
                        if(contact.Current_Join_Date__c == null){
                            date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                            relatedContact.Current_Join_Date__c = minDate;
                            // Update Membership Expiry Date
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedContact.Membership_Expiry_Date__c = maxDate;
                            //Add in the update contact list
                            UpdateFlag = True;
                        } 
                        else {
                            // Update Membership Expiry Date when another membership taken
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedContact.Membership_Expiry_Date__c = maxDate;
                            //Add in the update contact list
                            UpdateFlag = True;
                        }
                    } 
                } 
                else if (optcode == 2){
                    // Reinstated account membership
                    if(termrec.OrderApi__Is_Active__c){
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                        
                    } 
                    /** else {
                        // Renewed account membership
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    } **/
                } 
                else if (optcode == 3) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Cancellation for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = cancellationDate;
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                else if (optcode == 4) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Expired for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = subscriptionPaidThroughDate;
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                // If the update contact flag is True
                if(UpdateFlag == True){
                    uniqueContactsMap.put(relatedContact.id,relatedContact);
                }
            }
            //Update DML statement
            if(uniqueContactsMap.size() > 0){
                List<Contact> contactsToUpdate = new List<Contact>(uniqueContactsMap.values());
                system.debug(' Dump 2 ' + contactsToUpdate);
                update contactsToUpdate;
            }
        }
    }

    
    // For contact entity type
    public static void updateContact(OrderApi__Renewal__c termrec, integer optcode) {
        
        // Create a map to store unique Contact records based on their Id
        Map<Id, Contact> uniqueContactsMap = new Map<Id, Contact>();
        
        if(termrec.OrderApi__Contact__c != null) {
            List<Contact> contacts = [select id, Initial_Join_Date__c,Initial_Membership_Type__c,Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c,no_of_Renewals__c,(select OrderApi__Contact__c,OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c, OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c,OrderApi__Term__r.OrderApi__Is_Active__c,OrderApi__Term__r.OrderApi__Term_End_Date__c,OrderApi__Term__r.OrderApi__Term_Start_Date__c,OrderApi__Item__r.name,OrderApi__Assigned_Date__c,OrderApi__Is_Unassigned__c,OrderApi__Unassigned_Date__c,OrderApi__Term__c from OrderApi__Assignments__r where OrderApi__Assigned_Date__c != null and OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c != null order by OrderApi__Assigned_Date__c asc) from contact where Id = :termrec.OrderApi__Contact__c];	
			// Calculate Membership tracking field values for a Contact
            for (Contact contact : contacts) {
                // Initialize Contact record
                Contact relatedContact = new Contact(Id = contact.id);			             
                // For calculating total membership days
                List<DateRange> allDateRanges = new List<DateRange>();
                
                // For calculating active membership term and assignment
                List<DateRange> memberActiveDateRanges = new List<DateRange>();
				memberActiveDateRanges = KeeptrackingHandler.contactActiveDateRange(contact,contact.OrderApi__Assignments__r);
                
                // Initialize helper class
                DateRangeHelper helperDate = new DateRangeHelper();
                boolean UpdateFlag = False;
                // Update Contact record when there is a active membership or assignments
                // 
                if(optcode == 1) {
                    // Individual Membership Purchase
                    if(memberActiveDateRanges.size() > 0) {
                        if(contact.Initial_Join_Date__c == null){
                            // compare first row terms and assignment to get value for initialize current join date and initial Membership type
                            collectionJoinDateMembershipType cmp = KeeptrackingHandler.compare(contact,contact.OrderApi__Assignments__r);
                            relatedContact.Initial_Join_Date__c = cmp.joinDate;
                            relatedContact.Initial_Membership_Type__c = cmp.membershipItem;
                            //Add in the update contact list
                            UpdateFlag = True;
                        }
                        if(contact.Current_Join_Date__c == null){
                            date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                            relatedContact.Current_Join_Date__c = minDate;
                            // Update Membership Expiry Date
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedContact.Membership_Expiry_Date__c = maxDate;
                            //Add in the update contact list
                            UpdateFlag = True;
                        } 
                        else {
                            // Update Membership Expiry Date when another membership taken
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedContact.Membership_Expiry_Date__c = maxDate;
                            //Add in the update contact list
                            UpdateFlag = True;
                        }
                    } 
                } 
                else if (optcode == 2) {
                    // Renewal of the Individual Membership
                    // Add the future term in the active Membership Date Range
                    // reinstated Term
                    if(termrec.OrderApi__Is_Active__c){
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                        
                    } else {
                        // Renewal before expiry
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    }
                } 
                else if (optcode == 3) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Cancellation for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = KeeptrackingHandler.getCancellationDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                else if (optcode == 4) {
                    if(!(memberActiveDateRanges.size() > 0)) {
                        // Expired for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = KeeptrackingHandler.getSubscriptionPaidThroughDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                // If the update contact flag is True
                if(UpdateFlag == True){
                    uniqueContactsMap.put(relatedContact.id,relatedContact);
                }
            }
            //Update DML statement
            if(uniqueContactsMap.size() > 0){
                List<Contact> contactsToUpdate = new List<Contact>(uniqueContactsMap.values());
                system.debug(' Dump 1 ' + contactsToUpdate);
                update contactsToUpdate;
            }
        }
    }

    // For contact entity type
    public static void updateContactAssignment(Contact con, OrderApi__Renewal__c termrec, integer optcode) {
        
        // Create a map to store unique Contact records based on their Id
        Map<Id, Contact> uniqueContactsMap = new Map<Id, Contact>();
        
        if(con != null) {
            List<Contact> contacts = [select id, Initial_Join_Date__c,Initial_Membership_Type__c,Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c,no_of_Renewals__c,(select OrderApi__Contact__c,OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c, OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c,OrderApi__Term__r.OrderApi__Is_Active__c,OrderApi__Term__r.OrderApi__Term_End_Date__c,OrderApi__Term__r.OrderApi__Term_Start_Date__c,OrderApi__Item__r.name,OrderApi__Assigned_Date__c,OrderApi__Is_Unassigned__c,OrderApi__Unassigned_Date__c,OrderApi__Term__c from OrderApi__Assignments__r where OrderApi__Assigned_Date__c != null and OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c != null order by OrderApi__Assigned_Date__c asc) from contact where Id = :con.id];	
			// Calculate Membership tracking field values for a Contact
            for (Contact contact : contacts) {
                // Initialize Contact record
                Contact relatedContact = new Contact(Id = contact.id);			             
                // For calculating total membership days
                List<DateRange> allDateRanges = new List<DateRange>();
                
                // For calculating active membership term and assignment
                List<DateRange> memberActiveDateRanges = new List<DateRange>();
				memberActiveDateRanges = KeeptrackingHandler.contactActiveDateRange(contact,contact.OrderApi__Assignments__r);
                
                // Initialize helper class
                DateRangeHelper helperDate = new DateRangeHelper();
                boolean UpdateFlag = False;
                // Update Contact record when there is a active membership or assignments
                // 
                if(optcode == 1) {
                    // New Assignment
                    if(memberActiveDateRanges.size() > 0) {
                        if(contact.Initial_Join_Date__c == null){
                            // compare first row terms and assignment to get value for initialize current join date and initial Membership type
                            collectionJoinDateMembershipType cmp = KeeptrackingHandler.compare(contact,contact.OrderApi__Assignments__r);
                            relatedContact.Initial_Join_Date__c = cmp.joinDate;
                            relatedContact.Initial_Membership_Type__c = cmp.membershipItem;
                            //Add in the update contact list
                            UpdateFlag = True;
                        }
                        if(contact.Current_Join_Date__c == null){
                            date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                            relatedContact.Current_Join_Date__c = minDate;
                            // Update Membership Expiry Date
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedContact.Membership_Expiry_Date__c = maxDate;
                            //Add in the update contact list
                            UpdateFlag = True;
                        } 
                        else {
                            // Update Membership Expiry Date when another membership taken
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedContact.Membership_Expiry_Date__c = maxDate;
                            //Add in the update contact list
                            UpdateFlag = True;
                        }
                    } 
                } 
                else if (optcode == 2){
                    // Reinstated account membership
                    if(termrec.OrderApi__Is_Active__c){
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                        
                    } else {
                        // Renewed account membership
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    }
                } 
                else if (optcode == 3) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Cancellation for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = KeeptrackingHandler.getCancellationDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                else if (optcode == 4) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Expired for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = KeeptrackingHandler.getSubscriptionPaidThroughDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                // If the update contact flag is True
                if(UpdateFlag == True){
                    uniqueContactsMap.put(relatedContact.id,relatedContact);
                }
            }
            //Update DML statement
            if(uniqueContactsMap.size() > 0){
                List<Contact> contactsToUpdate = new List<Contact>(uniqueContactsMap.values());
                system.debug(' Dump 2 ' + contactsToUpdate);
                update contactsToUpdate;
            }
        }
    }

    
    // For account entity type
    public static void updateAccount(OrderApi__Renewal__c termrec, integer optcode) {
        
        // Create a map to store unique Contact records based on their Id
        Map<Id, Account> uniqueAccountsMap = new Map<Id, Account>();
        
        if(termrec.OrderApi__Account__c != null) {
            
            List<Account> accounts = [select id, Initial_Join_Date__c,Initial_Membership_Type__c,Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c,no_of_Renewals__c from Account where Id = :termrec.OrderApi__Account__c];	

            for (Account account : accounts) {
                // Initialize Account record
                Account relatedAccount = new Account(Id = account.id);			             
                // For calculating total membership days
                List<DateRange> allDateRanges = new List<DateRange>();
                
                // For calculating active total membership days
                List<DateRange> memberActiveDateRanges = new List<DateRange>();
                
                List<OrderApi__Renewal__c> terms = [SELECT id,OrderApi__Item__r.name,OrderApi__Subscription__r.OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Sales_Order_Line__c,OrderApi__Is_Active__c,OrderApi__Term_Start_Date__c,OrderApi__Term_End_Date__c,OrderApi__Sales_Order_Line__r.OrderApi__Is_Renewal__c FROM  OrderApi__Renewal__c where OrderApi__Account__c = :account.Id and  OrderApi__Entity__c = 'account' order by OrderApi__Term_Start_Date__c asc];	
                
                // Loop through all the Terms of a Contact	
                for (OrderApi__Renewal__c termRecord : terms) {
                    // Push all the active Terms in a date range collection to retrive the Earliest Date
                    if(termRecord.OrderApi__Subscription__r.OrderApi__Is_Active__c == True && termRecord.OrderApi__Is_Active__c == True){
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termRecord.OrderApi__Term_Start_Date__c, termRecord.OrderApi__Term_End_Date__c));
                    }
                }
                
                // Initialize helper class
                DateRangeHelper helperDate = new DateRangeHelper();
                boolean UpdateFlag = False;
                // Update Account record when there is a active membership or assignments
                if(optcode == 5) {
                    // Program Membership Purchased
                    if(memberActiveDateRanges.size() > 0) {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);
                        if(account.Initial_Join_Date__c == null){
                            relatedAccount.Initial_Join_Date__c = minDate;
                            relatedAccount.Initial_Membership_Type__c = KeeptrackingHandler.getItemNameByTerm(termrec.OrderApi__Item__c);
                            UpdateFlag = True;
                        }
                        if(account.Current_Join_Date__c == null){
                            relatedAccount.Current_Join_Date__c = minDate;
                            // Update Membership Expiry Date
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedAccount.Membership_Expiry_Date__c = maxDate;
                            UpdateFlag = True;
                        }
                        // If Term End is changed
                        if(account.Current_Join_Date__c != null){
                            // Update Membership Expiry Date
                            date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                            relatedAccount.Membership_Expiry_Date__c = maxDate;
                            UpdateFlag = True;
                        }
                    } 
                } 
                else if (optcode == 6){
                    // Renewal of the Program Membership
                    // Add the future term in the active Membership Date Range
                    if(termrec.OrderApi__Is_Active__c){
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedAccount.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedAccount.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    } else {
                        memberActiveDateRanges.add(new KeeptrackingHandler.DateRange(termrec.OrderApi__Term_Start_Date__c, termrec.OrderApi__Term_End_Date__c));
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedAccount.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    }
                } 
                else if (optcode == 7) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Cancellation Program Membership
                        relatedAccount.Current_Join_Date__c = null;
                        relatedAccount.Membership_Expiry_Date__c = KeeptrackingHandler.getCancellationDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedAccount.Days_Continuous_Membership__c = null;
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedAccount.Current_Join_Date__c = minDate;
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedAccount.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    }
                }
                else if (optcode == 8) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Expired Program Membership
                        relatedAccount.Current_Join_Date__c = null;
                        relatedAccount.Membership_Expiry_Date__c = KeeptrackingHandler.getSubscriptionPaidThroughDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedAccount.Days_Continuous_Membership__c = null;
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedAccount.Current_Join_Date__c = minDate;                        
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedAccount.Membership_Expiry_Date__c = maxDate;
                        UpdateFlag = True;
                    }
                }
                
                // If term and assignment records exists
                if(UpdateFlag == True){
                    uniqueAccountsMap.put(relatedAccount.id,relatedAccount);
                }
            }
            
            //Update DML statement
            if(uniqueAccountsMap.size() > 0){
                List<Account> accountsToUpdate = new List<Account>(uniqueAccountsMap.values());
                update accountsToUpdate;
            }
        }
    }
    

    public static void updateAssignment(SObject assignmenttermrec, integer optcode) {
        
        // Create a map to store unique Contact records based on their Id
        Map<Id, Contact> uniqueContactsMap = new Map<Id, Contact>();
        ID ContactId = null;
        OrderApi__Assignment__c assignmentrec;
        OrderApi__Renewal__c termrec;
        if (assignmenttermrec instanceof OrderApi__Assignment__c) {
            assignmentrec = (OrderApi__Assignment__c)assignmenttermrec;
            ContactId = assignmentrec.OrderApi__Contact__c;
        }
        else if (assignmenttermrec instanceof OrderApi__Renewal__c) {
            termrec = (OrderApi__Renewal__c)assignmenttermrec;
            ContactId = termrec.OrderApi__Contact__c;
        }
        
        if(ContactId != null) {
            List<Contact> contacts = [select id, Initial_Join_Date__c,Initial_Membership_Type__c,Current_Join_Date__c,Membership_Expiry_Date__c,Total_Days_Membership__c,Days_Continuous_Membership__c,no_of_Renewals__c,(select OrderApi__Contact__c,OrderApi__Is_Active__c,OrderApi__Subscription__r.OrderApi__Status__c,OrderApi__Subscription__r.OrderApi__Is_Cancelled__c,OrderApi__Subscription__r.OrderApi__Cancelled_Date__c, OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c,OrderApi__Term__r.OrderApi__Is_Active__c,OrderApi__Term__r.OrderApi__Term_End_Date__c,OrderApi__Term__r.OrderApi__Term_Start_Date__c,OrderApi__Item__r.name,OrderApi__Assigned_Date__c,OrderApi__Is_Unassigned__c,OrderApi__Unassigned_Date__c,OrderApi__Term__c from OrderApi__Assignments__r where OrderApi__Assigned_Date__c != null and OrderApi__Subscription__r.OrderApi__Paid_Through_Date__c != null order by OrderApi__Assigned_Date__c asc) from contact where Id = :ContactId];	
			// Calculate Membership tracking field values for a Contact
            for (Contact contact : contacts) {
                // Initialize Contact record
                Contact relatedContact = new Contact(Id = contact.id);			             
                // For calculating total membership days
                List<DateRange> allDateRanges = new List<DateRange>();
                
                // For calculating active membership term and assignment
                List<DateRange> memberActiveDateRanges = new List<DateRange>();
				memberActiveDateRanges = KeeptrackingHandler.contactActiveDateRange(contact,contact.OrderApi__Assignments__r);
                
                // Initialize helper class
                DateRangeHelper helperDate = new DateRangeHelper();
                boolean UpdateFlag = False;
                // Update Contact record when there is a active membership or assignments
                // 
                if (optcode == 3) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Cancellation for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = assignmentrec.OrderApi__Unassigned_Date__c;
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;                        
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                else if (optcode == 4) {
                    if(memberActiveDateRanges.size() == 0) {
                        // Expired for Individual Membership
                        relatedContact.Current_Join_Date__c = null;
                        relatedContact.Membership_Expiry_Date__c = KeeptrackingHandler.getSubscriptionPaidThroughDateByTerm(termrec.OrderApi__Subscription__c);
                        relatedContact.Days_Continuous_Membership__c = null;
                        //Add in the update contact list
                        UpdateFlag = True;
                    } else {
                        date minDate = helperDate.getMinDate(memberActiveDateRanges);                            
                        relatedContact.Current_Join_Date__c = minDate;                        
                        date maxDate = helperDate.getMaxDate(memberActiveDateRanges);
                        relatedContact.Membership_Expiry_Date__c = maxDate;
                        //Add in the update contact list
                        UpdateFlag = True;
                    }
                }
                // If the update contact flag is True
                if(UpdateFlag == True){
                    uniqueContactsMap.put(relatedContact.id,relatedContact);
                }
            }
            //Update DML statement
            if(uniqueContactsMap.size() > 0){
                List<Contact> contactsToUpdate = new List<Contact>(uniqueContactsMap.values());
                system.debug(' Dump 2 ' + contactsToUpdate);
                update contactsToUpdate;
            }
        }
    }


    // Unassigned assignment
    public static void onUpdateAssignment(Map<Id, OrderApi__Assignment__c> newAssign, Map<Id, OrderApi__Assignment__c> oldAssign) {
        if(newAssign.size() == 1){
            system.debug('I am here assignment');
            for(OrderApi__Assignment__c obj : newAssign.values()) {
                // Assignment Unassigned
                if(obj.OrderApi__Is_Unassigned__c && obj.OrderApi__Is_Unassigned__c != oldAssign.get(obj.Id).OrderApi__Is_Unassigned__c) {
                     system.debug('I am here assignment 1');
                    if(obj.OrderApi__Subscription__c != null && obj.OrderApi__Contact__c !=null && obj.OrderApi__Assigned_Date__c <= System.today() && obj.OrderApi__Term__c != Null && obj.OrderApi__Unassigned_Date__c == System.today() ){
                        List<OrderApi__Renewal__c> terms = [SELECT Id FROM OrderApi__Renewal__c where id = :obj.OrderApi__Term__c and OrderApi__Subscription__r.OrderApi__Status__c = 'Active' and OrderApi__Is_Active__c = True limit 1];
                        if(terms.size() > 0){
                            system.debug('I am here assignment 2');
                            // Update Contact as per the changes in assignment
                            KeeptrackingHandler.updateAssignment(obj, 3);
                        }						
                    }
                }
            }
        }
    }
}