public class AccountManager {
    
    // Method to create a new Account
    public static void createAccount(String name) {
        Account acc = new Account(Name = name);
        System.debug('');
        insert acc;
    }
    
    // Method to retrieve an Account by its Id
    public static Account getAccountById(Id accountId) {
        return [SELECT Id, Name FROM Account WHERE Id = :accountId];
    }
    
    // Method to update an Account's name
    public static void updateAccountName(Id accountId, String newName) {
        Account acc = [SELECT Id, Name FROM Account WHERE Id = :accountId];
        acc.Name = newName;
        update acc;
    }
    
    // Method to delete an Account by its Id
    public static void deleteAccount(Id accountId) {
        Account acc = [SELECT Id FROM Account WHERE Id = :accountId];
        delete acc;
    }
    
    // Method to retrieve all Accounts
    public static List<Account> getAllAccounts() {
        return [SELECT Id, Name FROM Account];
    }
}