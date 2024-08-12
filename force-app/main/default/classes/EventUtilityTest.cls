@isTest
public class EventUtilityTest {
    @isTest
    private static void testEventStatusLength(){
       String res =EventUtility.eventPrioirity('IND');
       System.assertEquals(null,res);
    }
    
    @isTest
    private static void testHighPri(){
       String res =EventUtility.eventPrioirity('CA');
       System.assertEquals('High',res);
    }
    
     @isTest
    private static void testMediumPri(){
       String res =EventUtility.eventPrioirity('MA');
       System.assertEquals('Medium',res);
    }

}