export interface type_agency {
    partId: number;
    agencyAssignment: {
        agencyId: number;
        identifierCode: string;
        agencyName: string;
    },
    paasSequence: number;
    paasAdministratorYN: boolean;
    roles: [string];
}



