import { type_options } from '@/app/_nonRoutingAssets/types/data-types'

export interface type_participantDetails {
  ccn: string,
  sequenceNumber: number,
  fullName: string | null,
  surname: string,
  givenOne: string,
  givenTwo: string | null,
  givenThree: string | null,
  surnameUpper: string,
  surnameSoundex: string,
  givenNameOneUppper: string,
  birthDate: string,
  organizationName: string | null,
  organizationNameUpper: string | null,
  organizationNameSoundex: string |null,
  title: {
    code: string | null,
    description: string | null
  },
  gender: {
    code: string | null,
    description: string | null
  },
  organizationType: {
    code: string | null,
    description: string | null
  },
  nameType: {
    code: string,
    description: string
  },
  rotaInitials: string | null,
  participant: {
    partId: number,
    type: {
      code: string,
      description: string | null
    },
    userId: string,
    police: boolean,
    businessType: {
      code: string | null,
      description: string | null
    },
    fps: {
      code: string | null,
      description: string | null
    },
    deceased: boolean,
    deceasedDate: string | null,
    gangMember: boolean,
    birthRegistrationNumber: string | null,
    csNumber: string | null,
    cpicFileNumber: string | null,
    hroip: boolean,
    icbcClientNumber: string | null,
    hroipComment: string | null,
    hroipFederal: boolean,
    sealCalcRequired: boolean,
    sealCalcDtm: string | null,
    doLto: boolean,
    rvo: boolean,
    ccn: string
  }
}

export interface type_participantAssignment {
  partId: number,
  userId: string | null,
  partCCN: string,
  assignmentCCN: string,
  fullName: string | null,
  agency: {
    id: number,
    name: string,
    addressLineOne: string | null,
    shortName: string | null,
    identifierCode: string,
    addressLineTwo: string | null,
    addressLineThree: string | null,
    postalCode: string | null,
    contactName: string | null,
    contactPhone: string | null,
    contactFaxNumber: string | null,
    witNotifUnitPhone: string | null,
    justinSiteYN: boolean | null,
    observersDstYN: boolean  | null,
    activeYN: boolean | null,
    email: string | null,
    timeZoneCode: string | null,
    mailingAddress: string | null,
    deliveryMethod: string | null,
    recieveFaxCoverPageYN: boolean | null,
    rcmpDivisionCode: string | null,
    crownRegionCode: string | null,
    fileDesignationYN: boolean | null,
    ccn: string | null
  },
  identificationDetails: {
    ccn: string,
    sequenceNumber: number,
    surname: string,
    givenOne: string | null,
    givenTwo: string | null,
    givenThree: string | null
  },
  employeeType: {
    code: string | null,
    description: string | null
  },
  employeeSubType: {
    code: string | null,
    description: string | null
  },
  honorificCode: string | null,
  administratorYN: boolean | null,
  approvingOfficerYN: boolean  | null,
  paasCode: string | null,
  paasSecondCode: string | null,
  paasSequence: number | null, //TODO: should not be null as needed for ie; commitments
  csoUserYN: boolean | null,
  startDate: string | null,
  endDate: string | null,
  partAgencyRelTypeCode: string | null,
  rccAccessLevel: {
    code: string,
    description: string
  },
  roles: (string | undefined)[],
  policeYN: boolean | null,
  demsUserYN: boolean | null,
  crownCoordYN: boolean | null
}

export interface type_policeShiftDuty {
  agencyId: number,
  ladderSequenceNumber: number,
  ladderNumber: number,
  ladderDescription: string,
  shiftType: {
    code: string,
    description: string
  },
  dutyType: {
    code: string,
    description: string
  }
}

export interface type_policeShift_orig {
  agencyId: number,
  partId: number,
  sequenceNumber: number,
  startDate: string,
  lastChanged: string | null,
  lastChangedDate: string | null,
  shiftLadder: {
    agencyId: number,
    ladderSequenceNumber: number,
    ladderNumber: number,
    ladderDescription: string | null
  },
  policeShiftType: {
    code: string,
    description: string | null
  },
  weightFactor: {
    code: number
  },
  inits: string | null,
  current: boolean,
  ccn: string
}

export interface type_policeShift {
  agencyId: number,
  partId: number,
  seqNumber: number,
  startDate: string,
  lastChanged: string | null,
  lastChangedDate: string | null,
  shiftLadderAgencyId: number,
  shiftLadderLadderSequenceNumber: number,
  shiftLadderLadderNumber: number,
  shiftLadderLadderDescription: string | null,
  policeShiftTypeCode: string,
  policeShiftTypeDescription: string | null,
  weightFactorCode: number,
  inits: string | null,
  current: boolean,
  ccn: string
}

export interface type_policeDutyType_orig {
  agencyId: number,
  partId: number,
  sequenceNumber: number,
  dutyTypeAgencyId: number,
  effectiveDate: string,
  auditDetails: {
    entryDate: string,
    entryUserId: string,
    updateDate: string,
    updateUserId: string
  },
  policeDutyType: {
    code: string,
    description: string
  },
  inits: string,
  current: boolean,
  ccn: string
}

export interface type_policeDutyType {
  agencyId: number,
  partId: number,
  sequenceNumber: number,
  dutyTypeAgencyId: number,
  effectiveDate: string,
  auditDetailsEntryDate: string,
  auditDetailsEntryUserId: string,
  auditDetailsUpdateDate: string,
  auditDetailsUpdateUserId: string
  policeDutyTypeCode: string,
  policeDutyTypeDescription: string,
  inits: string,
  current: boolean,
  ccn: string
}

export interface type_psSelectTabState {
  agencyDDL: type_options[] | null,
  dutyTypeDDL: type_options[] | null,
  shiftDDL: type_options[] | null,
  dtRight: type_participantAssignment[] | null,
  dtLeft: type_participantAssignment[] | null,
  currentAgencyId: string, 
  currentActiveFilterCode: string, 
  currentDutyTypeCode: string, 
  currentShiftLadderSequence: string, 
}

export interface type_policeCommitmentsRequest {
    sessionAgencyId: number | undefined,
    agencyId: number | null | undefined,
    partId: number | null | undefined;
    sequenceNumber: number | null | undefined,
    endDate: string | null | undefined;
    startDate: string | null | undefined;
    mdocJustinNo?: string | null | undefined;
}

export interface type_policeCommitment {
    partId: number,
    appearanceDate: string | null,
    appearanceTime: string | null,
    room: { 
        code: string | null, 
        description: string | null;
    },
    confirmed: boolean | null,
    commitment: string | null,
    commitmentDate: string | null,
    appearanceId: number | null,
    agencyIdentifier: { 
        code: string | null, 
        description: string | null;
    },
    agencyName: string | null,
    courtFileNumber: string | null,
    agencyFileNumber: string | null,
    accusedName: string | null,
    charge: string | null,
    appearanceReason: { 
        code: string | null, 
        description: string | null; 
    },
    initial: string | null;
}

export interface type_policeAssignmentType {
  entryDate: string,
  entryUserId: string,
  updateDate: string | null,
  updateUserId: string | null,
  type: {
    code: string,
    description: string
  },
  weightFactor: {
    code: string,
    description: string
  },
  ccn: string
}

export interface type_policeAssignment_orig {
  entryDate: string,
  entryUserId: string,
  updateDate: string | null,
  updateUserId: string | null,
  entryUserName: string,
  updateUserName: string | null,
  type: {
    code: string,
    description: string
  },
  agencyId: number,
  partId: number,
  sequenceNumber: number,
  startDate: string,
  endDate: string,
  conflict: boolean,
  initials: string,
  ccn: string,
  specialAssignment: {
    agencyId: number,
    type: {
      code: string,
      description: string
    },
    startDate: string,
    endDate: string,
    weightFactor: {
      code: string,
      description: string
    },
    ccn: string
  }
}

export interface type_policeAssignment {
  index: number,
  entryDate: string,
  entryUserId: string,
  updateDate: string | null,
  updateUserId: string | null,
  entryUserName: string,
  updateUserName: string | null,
  typeCode: string,
  typeDescription: string,
  agencyId: number,
  partId: number,
  sequenceNumber: number,
  startDate: string,
  endDate: string,
  conflict: string,
  initials: string,
  ccn: string,
  specialAssignmentAgencyId: number,
  specialAssignmentTypeCode: string,
  specialAssignmentTypeDescription: string,
  specialAssignmentStartDate: string,
  specialAssignmentEndDate: string,
  specialAssignmentWeightFactorCode: string,
  specialAssignmentWeightFactorDescription: string,
  specialAssignmentCcn: string,
}

export interface type_policeAssignment_param_searchId {
  partId: number | null,
  sequence: number | null,
}

export interface type_policeAssignment_param {
  startDate: string | null,
  endDate: string | null,
  searchIds: type_policeAssignment_param_searchId[] ,
}