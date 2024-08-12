@isTest
public class UpdateAccountsTest {
    
    @isTest
    public static void testUpdateAccount(){
      Account account= new Account();
      account.Name='Test Account';
      account.Active__c='No';
      account.Rating='Cold';
      insert account;
       
      Contact contact = new Contact();
      contact.FirstName='Test';
      contact.LastName='Test';
      contact.AccountId=account.Id;
      insert contact;
       
      UpdateAccounts.updateAccount();
      Account updateAcc=[select Id,Active__C,Rating from Account where Id =:account.Id];
      System.assertEquals('Hot',updateAcc.Rating);
           
    }

}