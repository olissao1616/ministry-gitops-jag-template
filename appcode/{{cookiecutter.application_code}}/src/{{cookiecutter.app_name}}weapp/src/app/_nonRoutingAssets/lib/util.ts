export function getInitials(name: string | null | undefined) {
    if (!name)
        return '';

    return name?.replace(/[^a-zA-Z- ]/g, "")?.match(/\b\w/g)?.join("").toUpperCase();
}

export const validateRequired = (value: string | null | undefined) => !!value?.trim().length;

export const isExceedMaxLength = (value: string, maxLengh: number) => value.length > maxLengh;

export const isNumber = (value: string | null | undefined) => value ? !isNaN(Number(value)) : false;

export const isPositiveInteger = (value: string | null | undefined): boolean => {
    const number = Number(value);
    const isInt = Number.isInteger(number);
    const isPositive = number > 0;

    return isInt && isPositive;
}

const regex = /^(([1-9]\d*)[DANOX],)*([1-9]\d*)[DANOX]$/i;
export function isPatternValid({ value }: { value: string | null | undefined; }): boolean {
    return regex.test(value ? value : '');
}