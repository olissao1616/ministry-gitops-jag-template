import { getCurrentDate_YYYY_MM_DD } from "./dateUtils";

describe('getCurrentDate_YYYY_MM_DD', () => {
    it('should return currentDate', () => {
        const curDate = new Date().toLocaleDateString('en-ca');
        expect(getCurrentDate_YYYY_MM_DD()).toBe(curDate);
    });

    
});
