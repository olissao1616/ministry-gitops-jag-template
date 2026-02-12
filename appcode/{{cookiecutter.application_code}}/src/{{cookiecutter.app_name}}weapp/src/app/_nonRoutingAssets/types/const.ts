export const URL_APPLICATION_SELECT = "/protected";
export const URL_AGENCY_SELECT = "/protected/agency"
export const URL_MAINMENU = "/protected/mainmenu"
export const URL_CODETABLE = "/protected/mainmenu/codetable"
export const URL_PERSONNELSCHEDULE = "/protected/mainmenu/personnelschedule"
export const URL_PERSONNELAVAIL = "/protected/mainmenu/personnelavailability"
export const URL_COURTINQUIRY = "/protected/mainmenu/courtinquiry"
export const URL_COURTREPORTS = "/protected/mainmenu/courtreports"
export const URL_PROFILE = "/protected/profile"

export const DATA_FILTER_ALL = "all"
export const DATA_FILTER_FUTURE = "future"
export const DATA_FILTER_PAST = "past"

export const MAXLENGTH_DUTYTYPECODE = 10
export const MAXLENGTH_DUTYTYPEDESC = 50
export const MAXLENGTH_SPECIALASSIGNMENTCODE = 3
export const MAXLENGTH_SPECIALASSIGNMENTDESC = 50
export const MAXLENGTH_SHIFTLADDERDESC = 50

export const scheduleMaintenanceMenus = [
    { title: 'Schedule Maintenance', breadCrumbTitle: 'Personnel Schedule Maintenance', route: URL_PERSONNELSCHEDULE },
    { title: 'Code Table Maintenance', breadCrumbTitle: 'Code Table Maintenance', route: URL_CODETABLE }];
  
    export const inquiryMenus = [
    { title: 'Personnel Availability', breadCrumbTitle: 'Personnel Availability', route: URL_PERSONNELAVAIL },
    { title: 'Court Inquiry', breadCrumbTitle: 'Court Inquiry', route: URL_COURTINQUIRY },
    { title: 'Court Reports', breadCrumbTitle: 'Court Reports', route: URL_COURTREPORTS }
];

export const containerMenu = [
    { topTitle: 'Police Scheduling', pages: scheduleMaintenanceMenus },
    { topTitle: 'Inquiry', pages: inquiryMenus }
];
  
export const navMenus = [
    { title: 'Main Menu', route: URL_MAINMENU },
    { title: 'Administration', route: "" },
    { title: 'Profile', route: URL_PROFILE }
];