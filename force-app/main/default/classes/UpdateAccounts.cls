public class UpdateAccounts {
    public static void updateAccount(){
        List<Account> accountToBeUpdated = new List<Account>();
        Set<Id> accIdSet = new set<Id>();
        
        for(Contact contact :[Select Id, Account.Id from Contact where Name like '%Test%' and Account.Id !=null]){
            if(!accIdSet.contains(contact.Account.Id)){
                Account account = new Account();
                account.Id=contact.Account.Id;
                account.Active__c='Yes';
                account.Rating ='Hot';
                accountToBeUpdated.add(account);
                accIdSet.add(contact.Account.Id);
            } 
        }
        if(!accountToBeUpdated.isEmpty()){
            update accountToBeUpdated;
        }
    }

}