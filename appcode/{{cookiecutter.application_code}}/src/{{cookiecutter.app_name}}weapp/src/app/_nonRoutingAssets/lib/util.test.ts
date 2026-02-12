import { isExceedMaxLength, getInitials, isPositiveInteger, isNumber, isPatternValid, validateRequired } from './util';

describe('getInitials', () => {
    it('should return the initials of a name', () => {
        expect(getInitials('John Doe')).toBe('JD');
    });

    it('should return empty string if name is null', () => {
        expect(getInitials(null)).toBe('');
    });

    it('should return empty string if name is undefined', () => {
        expect(getInitials(undefined)).toBe('');
    });

    it('should ignore special characters and spaces', () => {
        expect(getInitials('John-Doe Smith')).toBe('JDS');
    });
});


describe('validateRequired', () => {
    it ('should return false if value is null', () => {
        expect(validateRequired(null)).toBe(false);
    });

    it ('should return false if value is undefined', () => {
        expect(validateRequired(undefined)).toBe(false);
    });

    it ('should return false if value is empty string', () => {
        expect(validateRequired('')).toBe(false);
    });

    it ('should return false if value is empty string v2', () => {
        expect(validateRequired(' ')).toBe(false);
    });

    it ('should return true if value is non blank', () => {
        expect(validateRequired('some string')).toBe(true);
    });    
});

describe('isPatternValid', () => {
    it('should return true if the value matches the pattern', () => {
        expect(isPatternValid({ value: '1D,2A,3N' })).toBe(true);
    });

    it('should return true if the value matches the pattern', () => {
        expect(isPatternValid({ value: '3N' })).toBe(true);
    });

    it('should return false if the value does not match the pattern', () => {
        expect(isPatternValid({ value: '1D,2A,3X' })).toBe(true);
    });

    it('should return false if the value does not match the pattern', () => {
        expect(isPatternValid({ value: '0D,2A,3X' })).toBe(false);
    });
    
    it('should return false if the value does not match the pattern', () => {
        expect(isPatternValid({ value: '2A,3X,0D,' })).toBe(false);
    });

    it('should return false if the value does not match the pattern', () => {
        expect(isPatternValid({ value: '1D,2A,3G' })).toBe(false);
    });

    it('should return false if the value does not match the pattern', () => {
        expect(isPatternValid({ value: '1D,2A,3X,' })).toBe(false);
    });

    it('should return false if the value is null', () => {
        expect(isPatternValid({ value: null })).toBe(false);
    });

    it('should return false if the value is undefined', () => {
        expect(isPatternValid({ value: undefined })).toBe(false);
    });

    it('should return false if the value is an empty string', () => {
        expect(isPatternValid({ value: '' })).toBe(false);
    });
});

describe('isExceedMaxLength', () => {
    it ('should return false if value is empty string, maxLen is 2', () => {
        expect(isExceedMaxLength('', 2)).toBe(false);
    });

    it ('should return false if value is abc, maxLen is 4', () => {
        expect(isExceedMaxLength('abc', 4)).toBe(false);
    });
    
    it ('should return false if value is abc, maxLen is 3', () => {
        expect(isExceedMaxLength('abc', 3)).toBe(false);
    });

    it ('should return true if value is abc, maxLen is 1', () => {
        expect(isExceedMaxLength('abc', 1)).toBe(true);
    });  
});

describe('isNumber', () => {
    it ('should return false if value is null', () => {
        expect(isNumber(null)).toBe(false);
    });

    it ('should return false if value is undefined', () => {
        expect(isNumber(undefined)).toBe(false);
    });

    it ('should return false if value is empty string', () => {
        expect(isNumber('')).toBe(false);
    });

    it ('should return false if value is abc', () => {
        expect(isNumber('abc')).toBe(false);
    });

    it ('should return true if value is 123.3', () => {
        expect(isNumber('123.3')).toBe(true);
    });

    it ('should return true if value is 2', () => {
        expect(isNumber('2')).toBe(true);
    });   
    
    it ('should return true if value is -2', () => {
        expect(isNumber('-2')).toBe(true);
    }); 
});

describe('isPositiveInteger', () => {
    it ('should return false if value is null', () => {
        expect(isPositiveInteger(null)).toBe(false);
    });

    it ('should return false if value is undefined', () => {
        expect(isPositiveInteger(undefined)).toBe(false);
    });

    it ('should return false if value is empty string', () => {
        expect(isPositiveInteger('')).toBe(false);
    });

    it ('should return false if value is abc', () => {
        expect(isPositiveInteger('abc')).toBe(false);
    });

    it ('should return false if value is 123.3', () => {
        expect(isPositiveInteger('123.3')).toBe(false);
    });

    it ('should return true if value is 2', () => {
        expect(isPositiveInteger('2')).toBe(true);
    }); 
    
    it ('should return false if value is -2', () => {
        expect(isPositiveInteger('-2')).toBe(false);
    }); 
});