import * as DateFns from "date-fns";

export const DF_YYYY_MM_DD = "yyyy-MM-dd";

export const DF_LEA_STANDARD = "dd-MMM-yyyy";
export const DF_LEA_LEGACY = "yyyy.MM.dd";

export const getCurrentDate_YYYY_MM_DD = () => {
    return DateFns.format(Date.now(), DF_YYYY_MM_DD);
}

const isDateContainTime = (dateStr : string) => {   
    //console.log("isDateContainTime dateStr: ", dateStr) 
    let dateSplit = dateStr.split(' ');
    // date contains time portion
    if (dateSplit && dateSplit.length > 1) {
        return true;
    } else {
        dateSplit = dateStr.split('T');
        if (dateSplit && dateSplit.length > 1) {
            return true;
        }
        return false;
    }
}

export const dateToYYYY_MM_DD = (dateStr: string | null) => {
    //console.log("dateToYYYY_MM_DD dateStr: ", dateStr) 
    if (dateStr) {
        dateStr = dateStr.toString();
        if (isDateContainTime(dateStr)) {
            return DateFns.format(dateStr, DF_YYYY_MM_DD);
        } else {
            return DateFns.format(DateFns.parseISO(dateStr), DF_YYYY_MM_DD);
        }
    }
    return '';
}


export const dateToDD_MMM_YYYY = (dateStr: string | null) => {
    //console.log("dateToDD_MMM_YYYY dateStr: ", dateStr) 
    if (dateStr) {
        dateStr = dateStr.toString();
        if (isDateContainTime(dateStr)) {
            return DateFns.format(dateStr, DF_LEA_STANDARD);
        } else {
            return DateFns.format(DateFns.parseISO(dateStr), DF_LEA_STANDARD);
        }
    }
    return '';
}

export const getTime = (dateStr: string | null) => {
    if (dateStr) {
        dateStr = dateStr.toString();
        if (isDateContainTime(dateStr)) {
            return DateFns.format(dateStr, 'p');
        } else {
            return '';
        }
    }
    return '';
}